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
  expect_true(all(
    c("track_id", "date_time", "X", "Y") %in% colnames(event_data)
  ))
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
  expect_true(all(
    c("track_id", "date_time", "X", "Y") %in% colnames(combined_data)
  ))
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
    tt_write_data(
      example_tt,
      file_prefix = non_existent_path,
      combined = FALSE
    ),
    "does not exist"
  )
})

test_that("tt_write_data writes times that tt_read_data reads back", {
  # times in a time zone other than UTC, with fractional seconds
  events <- data.frame(
    track_id = "a",
    lon = c(0, 1, 2),
    lat = 0,
    date_time = as.POSIXct(
      c("2024-07-01 12:00:00.5", "2024-07-01 13:00:00.25", "2024-12-01 12:00"),
      tz = "Europe/London"
    )
  )
  test_tt <- move2::mt_as_move2(
    sf::st_as_sf(events, coords = c("lon", "lat"), crs = 4326),
    time_column = "date_time",
    track_id_column = "track_id"
  )
  output_path <- file.path(tempdir(), "test_times")
  on.exit(unlink(paste0(output_path, c("_events.csv", "_metadata.csv"))))

  tt_write_data(test_tt, file_prefix = output_path)
  read_tt <- tt_read_data(
    paste0(output_path, "_events.csv"),
    col_track_id = "track_id",
    col_coords = c("X", "Y"),
    col_date_time = "date_time"
  )
  time_difference <- as.numeric(event_time(read_tt)) -
    as.numeric(event_time(test_tt))
  expect_true(all(abs(time_difference) < 1e-5))

  # times without fractional seconds are written to the second, in UTC
  utc_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  tt_write_data(utc_tt, file_prefix = output_path)
  written <- read.csv(paste0(output_path, "_events.csv"))
  expect_equal(written$date_time[1], "2024-01-01 12:00:00 UTC")
})
