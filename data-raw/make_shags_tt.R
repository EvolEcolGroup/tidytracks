library(dplyr)
library(tidytracks)
library(sf)

# make shags dataset from csv file

shags_meta <- read.csv(system.file("extdata/shag_tidytrack_meta.csv",
                                   package = "tidytracks"))

# add geometry column (colony location point) to metadata


shags_meta <- shags_meta %>%
  sf::st_as_sf(coords = c("colony_lon", "colony_lat"), 
               crs = 4326, remove = FALSE) %>%
   dplyr::rename(colony_coord = geometry) %>%
  dplyr::select(bird_id, colony_coord) %>%
  mutate(bird_id = paste0("KB_", substr(bird_id, nchar(bird_id)-1, nchar(bird_id))))%>%
  mutate (across(where(is.character), tolower))

head(shags_meta)

# get the events file

shags_csv <- system.file("extdata/shag_tidytrack_sample.csv", 
                         package = "tidytracks")

# open the file as df
shags_df <- read.csv(shags_csv)

colnames(shags_df)
head(shags_df)

# select only bird id, date_gmt, time_gmt, Longitude and Latitude and rename bird_id
shags_df <- shags_df %>%
  select(bird_id, date_gmt, time_gmt, longitude, latitude, sex)%>%
  mutate(bird_id = paste0("KB_", substr(bird_id, nchar(bird_id)-1, nchar(bird_id))))%>%
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
str(shags_tt)

colnames(show_meta(shags_tt))
head(shags_tt)

# split the trips, then truncate the points by number of trips

# index first to keep track of points after filtering

# add an index col first
shags_tt <- shags_tt %>%
  mutate(index = row_number())

shags_trips <- shags_tt %>%
  tt_split_trips(
    centre_col = "colony_coord",
    buffer_outbound = as_units(1, "km"),
    buffer_inbound = as_units(1, "km"),
    complete = TRUE # keep only complete trips
  )

# check number of trips per bird_id
shags_trips %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# instead of this which doesnt work, just chop diofferent % of the points off

# remove original bird id column

# truncate 2 trips from KB_29
# truncate 9 trips from KB_42
# truncate  8 trips from KB 43
# truncate 10 trips from KB_45

# add a column for trip_number and use the trip_id to assign trip numbers, 

shags_trips <- shags_trips %>%
  group_by(bird_id) %>%
  #add trip number (last number of trip_id)
  mutate(trip_number = as.numeric(gsub(".*_(\\d+)$", "\\1", trip_id))) %>%
  ungroup()

# show table of trip number and unique bird_id
shags_trips %>%
  group_by(bird_id, trip_number) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_number))
# just removing trip ids over those numbers not bird IDs

# remove trips over those numbers
shags_trips <- shags_trips %>%#
  filter(!(bird_id == "kb_29" & trip_number > 2),
         !(bird_id == "kb_42" & trip_number > 3),
         !(bird_id == "kb_43" & trip_number > 1),
         !(bird_id == "kb_45" & trip_number > 3),
         !(bird_id == "kb_27" & trip_number > 1)) %>%
  select(-trip_number) # remove trip_id column

# check number of trips per bird_id
shags_trips %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# remove a further 30% of points (the last 30% of points in each trip)
# shags_trips <- shags_trips %>%
#   group_by(bird_id) %>%
#   slice_head(prop = 0.8) %>%
#   ungroup()

# add N trips column to the events data

# now filter shags_tt by the index points retained in shags_trips
shags_tt_filtered <- shags_tt %>%
  filter(index %in% shags_trips$index)

# this worked, was a sneaky group_by

nrow(shags_trips)
nrow(shags_tt)
nrow(shags_tt_filtered)

# put shags_tt_filtered into shags_tt and remove the index column
shags_tt <- shags_tt_filtered %>%
  select(-index)

# latitude filter


shags_tt <- shags_tt %>%
  dplyr::filter(st_coordinates(geometry)[,2] < -5)

#todo: remove any points that still break the speed filter

# first add speed col
# then used lizzies code to flag points
# any points that break it, move to nearer the last point. IE replace
# them with the prev point +0.1 or similar

# save shags_tt as a csv
tt_write_data(shags_tt, file = "data-raw/shags_tt.csv", combined = TRUE)
?tt_write_data

# test splitting again

shags_tt_split <- shags_tt %>%
  tt_split_trips(
    centre_col = "colony_coord",
    buffer_outbound = as_units(1, "km"),
    buffer_inbound = as_units(1, "km"),
    complete = TRUE
  )

# how many trip_id per track_id
shags_tt_split %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# that truncating didnt work as re- evaluates, got to cut down even more drastically 
# for some trips? 
# we do not need 

usethis::use_data(shags_tt, overwrite = TRUE)
