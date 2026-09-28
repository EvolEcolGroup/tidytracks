# alternative version of example dataset with non-alphabetical track IDs and
# differing durations, to test track_ functions.

library(tidytracks)
tt_read_data(
  "./data-raw/raw_csv/example_tt_2.csv",
  col_track_id = "track_id",
  col_coords = c("lon", "lat"),
  col_date_time = "date_time",
  format_date_time = "%Y-%m-%d %H:%M:%S",
  time_zone = "UTC",
  crs = 4326
) -> example_tt_2
# add a metadata column
show_meta(example_tt_2)$sex <- c("male", "male", "female")
show_meta(example_tt_2)$nest_lon <- c(1.37, -2.44, -0.78)
show_meta(example_tt_2)$nest_lat <- c(0.06, -1.76, 0.43)

saveRDS(example_tt_2, file = "./tests/testthat/testdata/example_tt_2.rds")
