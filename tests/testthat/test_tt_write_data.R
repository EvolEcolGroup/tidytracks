# tt_write_data works with events CSV and meta CSV
test_that("tt_write_data works with events CSV and meta CSV", {
  
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    meta = test_path("testdata/test_tt_read_data_meta.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  output_path <- file.path(tempdir(), "test")
  tt_write_data(example_tt, file_prefix = output_path, combined = FALSE)
  # check that we have an event file with columns track_id, date_time, X and Y
  event_file <- paste0(output_path, "_events.csv")
  expect_true(file.exists(event_file))
  event_data <- read.csv(event_file)
  expect_true(all(c("track_id", "date_time", "X", "Y") %in% colnames(event_data)))
  # check that we have a meta file with column track_id and info
  meta_file <- paste0(output_path, "_metadata.csv")
  expect_true(file.exists(meta_file))
  meta_data <- read.csv(meta_file)
  # check that the colnames are the same as in show_meta(example_tt)
  expect_identical(colnames(meta_data), colnames(show_meta(example_tt)))
  
  # now try the combined version
  tt_write_data(example_tt, file_prefix = output_path, combined = TRUE)
  combined_file <- paste0(output_path, "_combined.csv")
  expect_true(file.exists(combined_file))
  combined_data <- read.csv(combined_file)
  # check that we have an event file with columns track_id, date_time, X and Y
  expect_true(all(c("track_id", "date_time", "X", "Y") %in% colnames(combined_data)))
  # check that we have meta columns as well
  expect_true(all(colnames(show_meta(example_tt)) %in% colnames(combined_data)))
})

# tt_write_data throws error when directory doesn't exist
test_that("tt_write_data throws error when directory doesn't exist", {
  
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    meta = test_path("testdata/test_tt_read_data_meta.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Try to write to a non-existent directory
  non_existent_path <- file.path(tempdir(), "nonexistent_dir", "test")
  expect_error(
    tt_write_data(example_tt, file_prefix = non_existent_path, combined = FALSE),
    "does not exist"
  )
})
  

  