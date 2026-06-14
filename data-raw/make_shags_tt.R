library(dplyr)
library(tidytracks)
library(sf)

# make shags dataset from csv file - need meta for a col coords
shags_meta <- read.csv(system.file("extdata/shag_tidytrack_meta.csv",
                                   package = "tidytracks"))

# make the colony cpords into a geometry col and select only this and track id
#rename bird_id to keep short and simple
# make all lower case
shags_meta <- shags_meta %>%
  sf::st_as_sf(coords = c("colony_lon", "colony_lat"), 
               crs = 4326, remove = FALSE) %>%
  dplyr::rename(colony_coord = geometry) %>%
  dplyr::select(bird_id, colony_coord) %>%
  mutate(bird_id = paste0("kb_", substr(bird_id, nchar(bird_id)-1, nchar(bird_id))))


head(shags_meta)

# get the events file
shags_csv <- system.file("extdata/shag_tidytrack_sample.csv", 
                         package = "tidytracks")

# open the file as df
shags_df <- read.csv(shags_csv)

# select bird id, date_gmt, time_gmt, longitude, latitude, sex
# rename bird_id,
# make all lowercase
shags_df <- shags_df %>%
  select(bird_id, date_gmt, time_gmt, longitude, latitude, sex)%>%
  mutate(bird_id = paste0("kb_", substr(bird_id, nchar(bird_id)-1, nchar(bird_id))))%>%
  mutate (across(where(is.character), tolower))
  
# read in the data using tt_read_data, including the metadata
shags_tt <- tt_read_data(events = shags_df,
                         col_track_id = "bird_id",
                         col_coords = c("longitude", "latitude"),
                         col_date_time = c("date_gmt", "time_gmt"),
                         format_date_time = "%d/%m/%Y %H:%M:%S",
                         meta = shags_meta,
                         time_zone = "UTC",
                         crs = 4326)

# latitude filter
shags_tt <- shags_tt %>%
  dplyr::filter(sf::st_coordinates(geometry)[,2] < -5)

# Split the trips to see how many points need to be truncated

# add index col first to keep track of points after filtering
shags_tt <- shags_tt %>%
  mutate(index = row_number())
unique(shags_tt$bird_id)

# split trips 
shags_trips <- shags_tt %>%
  tt_split_trips(
    centre_col = "colony_coord",
    buffer_outbound = as_units(1, "km"),
    buffer_inbound = as_units(1, "km"),
    complete = TRUE)

# check number of trips per bird_id
shags_trips %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# remove last 50% of of kb_17, kb_19,  kb_29
# remove last 30% of kb_27  
# don't change kb_38
# remove last 75% of points from kb_42, kb_10 and kb_45

shags_tt_truncated <- shags_tt %>%
  group_by(bird_id) %>%
  mutate(point_number = row_number(), 
         n_points = n()) %>%
  filter(bird_id == "kb_38" | bird_id == "kb_40" |
    !(bird_id %in% c("kb_17", "kb_19", "kb_29", "kb_45") &
        point_number > n_points * 0.5),
    !(bird_id == "kb_27" &
        point_number > n_points * 0.5),
    !(bird_id %in% c("kb_42", "kb_43") &
        point_number > n_points * 0.5)) %>%
  ungroup() %>%
  select(-point_number, -n_points)

# check how many points removed
nrow(shags_tt) - nrow(shags_tt_truncated)

# table of number of points per track in shags_tt and shags_tt_filtered
data.frame(
  bird_id = unique(shags_tt$bird_id),
  points_in_shags_tt = sapply(unique(shags_tt$bird_id), function(id) sum(shags_tt$bird_id == id)),
  points_in_shags_shags_tt_truncated = sapply(unique(shags_tt$bird_id), function(id) sum(shags_tt_truncated$bird_id == id)))

# split to check splits into fewer trips
shags_truncated_trips <- shags_tt_truncated %>%
  tt_split_trips(
    centre_col = "colony_coord",
    buffer_outbound = as_units(3, "km"),
    buffer_inbound = as_units(3, "km"),
    complete = TRUE)

# summarise number of trip_id per bird_id
shags_truncated_trips %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# this looks much better

# remove some intermediate data 
rm(shags_meta, shags_trips, shags_truncated_trips, shags_trips)

# filter shags_tt by index col to keep only the points in shags_trips_filtered
# rather than indexing can tt_truncated just be shags_ttt?

# yes, but remove the index col first to avoid confusion
shags_tt <- shags_tt_truncated %>%
  select(-index)

# how many rows removed from original?
nrow(shags_df) - nrow(shags_tt)

# tidy up
rm(shags_tt_truncated)



# speed filtering - flag any points that break speed filter and plot them

# we'll use to identify which points should be removed

shags_tt <- shags_tt %>%
  dplyr::mutate(point_id = 1:nrow(shags_tt))%>%
  dplyr::arrange(bird_id, date_time)

# take a copy of df
df_dups <- shags_tt

# add speed to following location
df_dups <- df_dups %>%
  dplyr::mutate(speed = tidytracks::event_speed(.)) %>%
  dplyr::mutate(speed = units::set_units(speed, "km/h")) %>%
  dplyr::mutate(speed_0 = ifelse(as.numeric(speed) == 0, TRUE, FALSE))
table(df_dups$speed_0, useNA="ifany") # only 1 points with speed 0

# flag any location which has the exact same lon and lat as the previous location

df_dups <- df_dups %>%
  dplyr::mutate(lon = sf::st_coordinates(.)[,1],
                lat = sf::st_coordinates(.)[,2]) %>%
  dplyr::group_by(bird_id) %>%
  dplyr::mutate(lon_prev = dplyr::lag(lon),
                lat_prev = dplyr::lag(lat)) %>%
  dplyr::mutate(dup_loc = ifelse(lon == lon_prev & lat == lat_prev, TRUE, FALSE)) %>%
  dplyr::ungroup()
table(df_dups$dup_loc, useNA="ifany") # also 1 so thats ok

# check the indices of the duplicates and the speed 0 points match perfectly

indices_speed_0 <- which(df_dups$speed_0 == TRUE) # the first of each duplicate set
indices_dup_loc <- which(df_dups$dup_loc == TRUE) # the second of each set
all(indices_speed_0+1 == indices_dup_loc) # TRUE, they match perfectly


# these are the points which are identified as duplicates
nrow(subset(df_dups, speed_0 == TRUE | dup_loc == TRUE))

head(shags_tt)

# get colony coords then make 0.5 km box around them
col_coords <- sf::st_coordinates(show_meta(shags_tt)$colony_coord[1]) # get colony coords from first row

# points all so close tp col and only 1 doesn't move so keep 

##Speed Filter

# add speed to df and summarise
shags_tt <- shags_tt %>%
  dplyr::mutate(speed = tidytracks::event_speed(.)) %>%
  dplyr::mutate(speed = units::set_units(speed, "km/h"))

shags_tt %>%
  summary()

#max speed is 950 

hist(shags_tt$speed, breaks = 100, xlim = c(0, 200))


# speed filter 1

nrow(shags_tt)
max_speed <- units::as_units(60, "km/h")


shags_tt_it_1 <- shags_tt %>%
  tidytracks::tt_clean_mcconnell(max_speed = max_speed)

nrow(shags_tt) - nrow(shags_tt_it_1)


# recalculate speeds

# add speed to df and summarise
shags_tt_it_1 <- shags_tt_it_1 %>%
  dplyr::mutate(speed = tidytracks::event_speed(.)) %>%
  dplyr::mutate(speed = units::set_units(speed, "km/h"))

# main issue is that one 188 km/h, is that at the end of a track? # plot kb40 with speeds

  shags_tt_it_2 <- shags_tt_it_1 %>%
  tidytracks::tt_clean_mcconnell(max_speed = max_speed)

# add speed to df and summarise
shags_tt_it_2 %>%
  dplyr::mutate(speed = tidytracks::event_speed(.)) %>%
  dplyr::mutate(speed = units::set_units(speed, "km/h"))%>%
  arrange(desc(speed))

# rerun filter to check
# not removing the 188 km/h so prob at the end of a track


df_check <- shags_tt_it_1 %>%
  arrange(bird_id, date_time) %>%
  group_by(bird_id) %>%
  mutate(
    is_last_point = row_number() == n(),
    is_penultimate = row_number() == n() - 1,
    is_first_point = row_number() == 1,
    is_second_point = row_number() == 2
  ) %>%
  ungroup()

df_check %>%
  filter(is_penultimate | is_last_point,
    as.numeric(speed) > 100) %>%
  select(bird_id, speed, is_last_point, is_penultimate)

# is penultimate point

# plot to double check

# none

kb_40 <- shags_tt_it_1 %>%
  filter(bird_id == "kb_40")

#add flags 

# flag points with speed >100, and the following point (so we can see which is wrong)
indices_high_speed <- which(as.numeric(kb_40$speed) > 80)
indices_following  <- indices_high_speed + 1
df_check$speed_flag <- FALSE
df_check$speed_flag[c(indices_high_speed, indices_following)] <- TRUE
table(kb_40$speed_flag, useNA="ifany") # 14 flagged points

# plot a map in leaflet, with a popup label showing the datetime field
library(leaflet)

# print those track ids within a sentence

# subset to one deployment to check - speeds over 70

# Ensure points are ordered by time
kb_40 <- df_check[order(kb_40$date_time), ]

# Create a track line from the points
track_line <- kb_40 %>%
  sf::st_geometry() %>%
  sf::st_cast("POINT") %>%
  sf::st_union() %>%
  sf::st_cast("LINESTRING")

leaflet(data = kb_40) %>%
  addTiles() %>%
  
  # Track line
  addPolylines(
    data = track_line,
    color = "black",
    weight = 2
  ) %>%
  
  # All points
  addCircleMarkers(
    lng = sf::st_coordinates(kb_40)[,1],
    lat = sf::st_coordinates(kb_40)[,2],
    radius = 3,
    color = ifelse(kb_40$speed_flag, "red", "blue"),
    popup = ~as.character(date_time)
  ) %>%
  
  # Highlight flagged points
  addCircleMarkers(
    data = subset(kb_40, speed_flag),
    lng = sf::st_coordinates(subset(kb_40, speed_flag))[,1],
    lat = sf::st_coordinates(subset(kb_40, speed_flag))[,2],
    radius = 8,
    color = "red",
    fill = FALSE,
    weight = 2
  )


# get indices of those 2 points

bad_points <- kb_40 %>%
  filter(speed_flag == TRUE)%>%
  select(point_id, speed_flag)%>%
  pull(point_id)

# points 820 and 821


# now keep everything in shags_tt except the points with these point_ids
shags_tt_filtered <- shags_tt %>%
  filter(!point_id %in% bad_points)%>%
  select(-point_id) # remove point_id col as no longer needed

# check summary of speeds in filtered data
shags_tt_filtered %>%
  dplyr::mutate(speed = tidytracks::event_speed(.)) %>%
  dplyr::mutate(speed = units::set_units(speed, "km/h"))%>%
  arrange(desc(speed)) %>%
  select(bird_id, date_time, speed)

# yeah think this worked!!

# rerun speed filter to check, hopefullyh removes all really bad points. may want to add in a few
# more weird ones t have tio run filter twice

speed_filter_check <- shags_tt_filtered %>%
  tidytracks::tt_clean_mcconnell(max_speed = max_speed)

#tidy up
rm(df_check, df_filtered, high_speed_points, indices_following, indices_high_speed, track_line)

# save into inst/extdata/csv_files (unsure where to put?)

# can't get tt_write_data to work so just make into a df and then save as csv


shags_tt <- shags_tt_filtered
# first drop geometry of the colony_coord
show_meta(shags_tt) <- show_meta(shags_tt) %>%
  mutate(colony_lon = sf::st_coordinates(colony_coord)[, "X"],
         colony_lat = sf::st_coordinates(colony_coord)[, "Y"] )%>%
  select(-colony_coord)

# now move sex and colony_coord to events
shags_tt <- shags_tt %>%
  as_event_column(c(colony_lon, colony_lat, sex))

# then separate geometry col into 'lon' and 'lat' col\
shags_tt <- shags_tt %>%
  mutate (lon = sf::st_coordinates(shags_tt)[,1],
          lat = sf::st_coordinates(shags_tt)[,2]) 


# convert to a df
shags_df_2 <- as.data.frame(shags_tt) %>%
  select(-geometry) 

# check
head(shags_df_2)


# write as a csv
write.csv(shags_df_2, file = "inst/extdata/csv_files/shags_example.csv", row.names = FALSE)

