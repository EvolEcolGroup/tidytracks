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
  # expect that all tese columns are present
  expect_true(all(expected_columns %in% names(result)))
  
  # there should be no missing data in this
  expect_true(all(result$proportion_missing == 0))
  
  # now generate some noise in the estimates (we add or remove 1 minute from
  # the date_time of some points, which should cause some missing data in the
  # original tibble)
  set.seed(1)
  test_tt_noisy <- test_tt %>%
    dplyr::mutate(date_time = date_time + 
                    lubridate::seconds(round(runif(dplyr::n(), min = 0, max = 60)))) %>%
    # convert back to date time
    dplyr::mutate(date_time = as.POSIXct(date_time, origin = "1970-01-01", tz = "UTC"))
  result_noisy <- tt_summary_health(test_tt_noisy)
})
