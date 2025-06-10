test_that("tt_read_track_data works with valid input", {
  skip()
  # Read in the data from a csv
  example_csv <- system.file("/extdata/csv_files/dataset_example_birdlife.csv",
                                     package = "tidytracks")
  
  example_tt <- tt_read_data(albatross_csv,
                               col_track_id = "track_id",
                               col_coords = c("longitude", "latitude"),
                               col_date_time = c("date_gmt", "time_gmt"))
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("scientific_name", "age", "breed_status") %in%
        names(show_meta(example_tt))))
  
  #@TODO we need tests for bring in a meta.csv, as well as various errors
})
