test_that("tt_summary_health gives the correct errors", {
  expect_error(
    tt_summary_health(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("tt_summary_health returns a data frame with expected columns", {
  # create the toy dataframe of longitude, latitude, date_time, bird_id
  # this has perfect data, so there should be no missing data in the output
  test_tt <- create_toy_tt()
  
  result <- tt_summary_health(test_tt)
  
  # check it's a tibble
  expect_true(inherits(result, "tbl_df"))
  # define the expected columns
  expected_columns <- c(move2::mt_track_id_column(test_tt),
                        "median_sampling_interval", "track_duration",
                        "expected_points", "actual_points", "proportion_missing")
  # expect that all these columns are present
  expect_true(all(expected_columns %in% names(result)))
  
  # there should be no missing data in this
  expect_true(all(result$proportion_missing == 0))
  
  # remove one event to create a gap and missingness in one track
  track_to_edit <- unique(event_track_id(test_tt))[1]
  row_to_remove <- which(event_track_id(test_tt) == track_to_edit)[10]
  test_tt_noisy <- test_tt[-row_to_remove, ]
  result_noisy <- tt_summary_health(test_tt_noisy)
  expect_true(any(result_noisy$proportion_missing > 0))

  # duplicate timestamps should not produce Inf/NaN or negative missingness
  test_tt_dup <- test_tt
  dup_rows <- which(event_track_id(test_tt_dup) == track_to_edit)
  test_tt_dup$date_time[dup_rows] <- test_tt_dup$date_time[dup_rows[1]]
  result_dup <- tt_summary_health(test_tt_dup)
  expect_true(all(is.finite(result_dup$expected_points)))
  expect_true(all(result_dup$proportion_missing >= 0))
  expect_true(all(result_dup$proportion_missing <= 1))
})
