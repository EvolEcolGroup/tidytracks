library(dplyr)
library(tidytracks)
library(sf)

# make shags dataset from csv file - need meta for a col coors

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

# select only bird id, date_gmt, time_gmt, Longitude and Latitude and rename bird_id,
# make all lowercase

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


# split the trips to see how many points need to be truncated

# add index col first to keep track of points after filtering

shags_tt <- shags_tt %>%
  mutate(index = row_number())

# split trips 

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

# remove 50% of end points of kb_17, kb_19,  kb_29
# 30% of kb_27 and 
# don't change kb_38
# remove last 75% of points from kb_42, kb_10 and kb_45


shags_tt_filtered <- shags_tt %>%
  group_by(bird_id) %>%
  mutate(point_number = row_number(),
    n_points = n()) %>%
  filter(
    !(bird_id %in% c("kb_17", "kb_19", "kb_29") &
        point_number > n_points * 0.5),
    !(bird_id == "kb_27" &
        point_number > n_points * 0.3),
    !(bird_id %in% c("kb_42", "kb_43", "kb_45") &
        point_number > n_points * 0.25)) %>%
  ungroup() %>%
  select(-point_number, -n_points)

# check how many removed

nrow(shags_tt_filtered)
nrow(shags_tt)

# table pf nuber of points per track in shags_tt and shags_tt_filtered
shags_tt %>%
  group_by(bird_id) %>%
  summarise(n_points = n()) %>%
  select(bird_id, n_points)

shags_tt_filtered %>%
  group_by(bird_id) %>%
  summarise(n_points = n()) %>%
  select(bird_id, n_points)

# split to check splits into fewer trips

shags_trips_filtered <- shags_tt_filtered %>%
  tt_split_trips(
    centre_col = "colony_coord",
    buffer_outbound = as_units(3, "km"),
    buffer_inbound = as_units(3, "km"),
    complete = TRUE # keep only complete trips
  )

# summarise number of trip_id per bird_id

shags_trips_filtered %>%
  group_by(bird_id) %>%
  summarise(n_trips = n_distinct(trip_id))

# this looks much better

# now filter shags_tt by the index col to keep only the points that are in shags_trips_filtered
shags <- shags_tt %>%
  filter(index %in% shags_trips_filtered$index) %>%
  select(-index)

# hpow many rows removed?

nrow(shags_tt) - nrow(shags)

# tidy up

rm(shags_tt, shags_df, shags_meta, shags_trips, shags_trips_filtered, shags_tt_filtered)

# write to a csv as combined, keep the col coord in the csv

# save into inst/extdata/csv_files (unsure where to put?)

?tt_write_data
tt_write_data(shags, "inst/extdata/csv_files/shags_example", combined = TRUE)

shags_csv <- read.csv(
  "inst/extdata/csv_files/shags_example_combined.csv",
  row.names = NULL
)


# no longer need usethin as going to source csv
