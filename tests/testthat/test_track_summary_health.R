test_that("track_summary_health gives the correct errors", {
  expect_error(
    track_summary_health(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("track_summary_health returns a data frame with expected columns", {
  # create the toy dataframe of longitude, latitude, date_time, bird_id
  # this has perfect data, so there should be no missing data in the output
  test_tt <- create_toy_tt()

  result <- track_summary_health(test_tt)

  # check it's a tibble
  expect_true(inherits(result, "tbl_df"))
  # define the expected columns
  expected_columns <- c(
    move2::mt_track_id_column(test_tt),
    "median_sampling_interval",
    "track_duration",
    "expected_points",
    "actual_points",
    "proportion_missing"
  )
  # expect that all these columns are present
  expect_true(all(expected_columns %in% names(result)))

  # there should be no missing data in this
  expect_true(all(result$proportion_missing == 0))

  # remove one event to create a gap and missingness in one track
  track_to_edit <- unique(event_track_id(test_tt))[1]
  row_to_remove <- which(event_track_id(test_tt) == track_to_edit)[10]
  test_tt_noisy <- test_tt[-row_to_remove, ]
  result_noisy <- track_summary_health(test_tt_noisy)
  expect_true(any(result_noisy$proportion_missing > 0))

  # duplicate timestamps should not produce Inf/NaN or negative missingness
  test_tt_dup <- test_tt
  dup_rows <- which(event_track_id(test_tt_dup) == track_to_edit)
  test_tt_dup$date_time[dup_rows] <- test_tt_dup$date_time[dup_rows[1]]
  result_dup <- track_summary_health(test_tt_dup)
  expect_true(all(is.finite(result_dup$expected_points)))
  expect_true(all(result_dup$proportion_missing >= 0))
  expect_true(all(result_dup$proportion_missing <= 1))
})

test_that("track_summary_health returns tracks in the order of the metadata", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # after ordering, the events are in the order a, b, c, whilst the metadata
  # is still in the order b, a, c
  example_tt_2 <- tt_order_time(example_tt_2)

  result <- track_summary_health(example_tt_2)
  expect_equal(as.character(result$track_id), c("b", "a", "c"))
  expect_equal(result$track_duration, as_units(c(5, 4, 3) * 20 * 60, "s"))
})

test_that("track_summary_health gives the times in seconds as units", {
  result <- track_summary_health(example_tt)
  expect_equal(units(result$median_sampling_interval)$numerator, "s")
  expect_equal(units(result$track_duration)$numerator, "s")
  # the duration is that of track_duration(), in seconds
  expect_equal(
    result$track_duration,
    unname(track_duration(example_tt, units = "s"))
  )
})
