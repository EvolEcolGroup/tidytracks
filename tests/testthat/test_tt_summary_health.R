testthat({
  test_that("tt_summary_health returns a data frame with expected columns", {
    # create the toy dataframe of longitude, latitude, date_time, bird_id
    # this has perfect data, so there should be no missing data in the output
    coords_df <- create_toy_df()
    
    # convert to a tidytracks object
    test_tt <- tt_read_data(events = coords_df,
                            col_track_id = "bird_id",
                            col_coords = c("longitude", "latitude"),
                            col_date_time = "date_time"
    )
    
    
    result <- tt_summary_health(test_tt)
    
    expect_true(inherits(result, "tbl_df"))
    # there should be no missing data in this
    expect_true(all(result$proportion_missing == 0))
    
    # now generate some noise in the estimates (we add or remove 1 minute from
    # the date_time of some points, which should cause some missing data in the
    # original tibble)
    test_tt_noisy <- test_tt %>%
      dplyr::mutate(date_time = date_time + 
                      lubridate::seconds(round(runif(dplyr::n(), min = 0, max = 60)))) %>%
      # convert back to date time
      dplyr::mutate(date_time = as.POSIXct(date_time, origin = "1970-01-01", tz = "UTC"))
    result_noisy <- tt_summary_health(test_tt_noisy)
  })
