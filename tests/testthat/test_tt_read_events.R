test_that("tt_read_track_data works with valid input", {
  skip()
  # Read in the data from a csv
  example_csv <- system.file("/extdata/csv_files/dataset_example_birdlife.csv",
                                     package = "tidytracks")
  
  
  
  # convert it to an sf object
  example_sf <- sf::st_as_sf(example_csv, coords = c("longitude", "latitude"), crs = 4326)
  # create a date-time column
  example_sf <- example_sf %>%
    mutate(date_time = lubridate::ymd_hms(paste(date_gmt, time_gmt))) %>%
    select(-c(date_gmt, time_gmt))
  # convert it to a move2 object
  example_mt <- move2::mt_as_move2(example_sf,
                               time_column = "date_time",
                               track_id_column = "track_id",
                               track_attributes = c("site_name", "colony_name",
                                                    "lat_colony", "lon_colony",
                                                    "device","bird_id", "age",
                                                    "sex", "breed_state", "breed_status"))

})
