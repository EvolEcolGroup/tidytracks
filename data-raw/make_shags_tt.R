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

# save into inst/extdata/csv_files (unsure where to put?)

# can't get tt_write_data to work so just make into a df and then save as csv

# first drop geometry of the colony_coord
show_meta(shags_tt) <- show_meta(shags_tt) %>%
  mutate(colony_lon = sf::st_coordinates(colony_coord)[, "X"],
         colony_lat = sf::st_coordinates(colony_coord)[, "Y"] )%>%
  select(-colony_coord)

# now move sex and colony_coord to events
shags_tt <- shags_tt %>%
  as_event_column(c(colony_lon, colony_lat, sex))

# then separate geometry col into 'lon' and 'lat' cols
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

