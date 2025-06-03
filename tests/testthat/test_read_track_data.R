test_that("tt_read_track_data works with valid input", {
  # Create a temporary file with valid track data
  read.csv("testdata/csv_files/dataset_example_birdlife.csv")

  # Call the function and check the output
  result <- read_track_data(temp_file)
  expect_true(is.data.frame(result))
  expect_equal(ncol(result), 3)
  expect_equal(nrow(result), 10)

  # Clean up
  unlink(temp_file)
})
