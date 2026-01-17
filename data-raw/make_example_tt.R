# make a very simple dataset of 3 individuals, with 5 obs per individual,
# used for examples

tt_read_data("./data-raw/raw_csv/example_tt.csv",
             col_track_id = "track_id",
             col_coords = c("lon", "lat"),
             col_date_time = "date_time",
             format_date_time = "%Y-%m-%d %H:%M:%S",
             time_zone = "UTC",
             crs = 4326) -> example_tt
usethis::use_data(example_tt, overwrite = TRUE)
