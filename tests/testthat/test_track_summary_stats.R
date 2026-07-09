test_that("track_summary_stats gives the correct errors", {
  # try running it on an object that isn't a move2 object
  expect_error(
    track_summary_stats(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("track_summary_stats correctly computes track summaries", {
  # create a simple trajectory that goes out and comes back along the longitude
  # axis
  set.seed(1)
  coords_df <- data.frame(
    longitude = c(
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      5,
      4,
      3,
      2,
      1,
      0.5,
      -2,
      -3,
      -4,
      -5,
      -3 - 1.2,
      -0.3,
      -0.1,
      1,
      3,
      4,
      2.1,
      0.3,
      0.7,
      2.1,
      4,
      3,
      1.3 # second individual
    ),
    latitude = rnorm(30, mean = 0, sd = 0.1) +
      c(
        rep(0, 6),
        rep(0.3, 5),
        rep(0.15, 7),
        rep(-0.3, 6),
        rep(0.1, 6)
      )
  )
  coords_df$date_time <- c(
    seq(
      from = as.POSIXct("2020-01-01 00:00:00"),
      by = "1 hour",
      length.out = 24
    ),
    seq(
      from = as.POSIXct("2020-02-10 00:00:00"),
      by = "1 hour",
      length.out = 6
    )
  )
  coords_df$bird_id <- paste0("id_", c(rep(1, 24), rep(2, 6)))
  coords_df$bird_id <- as.factor(coords_df$bird_id)

  # set up metadata for these events
  meta_df <- data.frame(
    bird_id = unique(coords_df$bird_id),
    species = c("species_a", "species_b")
  )
  meta_df$colony_sf <- sf_point_col(x = c(0, 0), y = c(0, 0), crs = 4326)

  # convert this df to a move2 object
  test_tt <- tt_read_data(
    events = coords_df,
    col_track_id = "bird_id",
    col_coords = c("longitude", "latitude"),
    col_date_time = "date_time",
    meta = meta_df
  )

  # plot to check
  # ggplot2::ggplot(test_tt) +
  #   # ggplot2::geom_sf(ggplot2::aes(color = date_time)) +
  #   ggplot2::geom_sf(ggplot2::aes(color = bird_id)) +
  #   ggplot2::geom_sf(data = move2::mt_track_lines(test_tt))

  # run the trip splitting with complete = FALSE (includes incomplete trips
  # and locations at centre)
  test_tt_split <- tt_split_trips(
    test_tt,
    centre_col = "colony_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  # check that the trip ids are correct
  expect_equal(length(unique(test_tt_split$trip_id)), 6)
  expect_equal(length(unique(test_tt_split$bird_id)), 2)

  # compute track summaries
  test_sums <- track_summary_stats(
    x = test_tt_split,
    centre_col = "colony_sf",
    units_duration = units::as_units(1, "hours")
  )

  # check that all the expected columns are present
  expected_cols <- c(
    move2::mt_track_id_column(test_tt_split),
    "tot_duration",
    "tot_distance",
    "max_latitude",
    "min_latitude",
    "max_longitude",
    "min_longitude",
    "max_dist_centre",
    "lat_at_max_dist_centre",
    "lon_at_max_dist_centre"
  )
  expect_true(all(expected_cols %in% colnames(test_sums)))

  # check that trip_nas have been removed, so number of trips is no longer the same
  expect_true(nrow(test_sums) < nrow(show_meta(test_tt_split)))

  # if we remove trip_nas from show_meta(test_tt_split), then the trip_ids in
  # sum_stats, should equal the trip_ids in show_meta
  trip_ids <- unique(event_track_id(test_tt_split))
  trip_na_ids <- trip_ids[grepl("_trip_na$", trip_ids)]
  meta_no_nas <- show_meta(test_tt_split)[
    !(show_meta(test_tt_split)[[move2::mt_track_id_column(test_tt_split)]] %in%
      trip_na_ids),
  ]
  expect_equal(
    test_sums[[move2::mt_track_id_column(test_tt_split)]],
    meta_no_nas[[move2::mt_track_id_column(test_tt_split)]]
  )

  # check the units of duration are as requested (hours)
  expect_true(
    as.character(base::units(test_sums$tot_duration)) == "h"
  )

  # check the units of distance are metres (unless we add a units argument
  #   for distance as well as duration)
  expect_true(
    as.character(base::units(test_sums$tot_distance)) == "m"
  )
  expect_true(
    as.character(base::units(test_sums$max_dist_centre)) == "m"
  )

  # TODO add tests that the values are correct

  # check that we have the same results if the centers have different projectoin
  # check if the centers have different projection
  show_meta(test_tt_split)$colony_sf <-
    sf::st_transform(show_meta(test_tt_split)$colony_sf, 5936)

  # compute track summaries
  test_sums2 <- track_summary_stats(
    x = test_tt_split,
    centre_col = "colony_sf",
    units_duration = units::as_units(1, "hours")
  )
  expect_identical(test_sums, test_sums2)

  # now test some errors for the centre_col argument
  expect_error(
    track_summary_stats(
      x = test_tt_split,
      centre_col = "non_existent_column",
      units_duration = units::as_units(1, "hours")
    ),
    "centre_col must be a column name in the metadata table"
  )
  expect_error(
    track_summary_stats(
      x = test_tt_split,
      centre_col = "species",
      units_duration = units::as_units(1, "hours")
    ),
    "centre_col must be a `sfc_POINT` column in the metadata table"
  )
  # remove the crs from the colony_sf column and check that we get the correct error
  show_meta(test_tt_split)$colony_sf <- sf_point_col(x = c(0, 0), y = c(0, 0))
  expect_error(
    track_summary_stats(
      x = test_tt_split,
      centre_col = "colony_sf",
      units_duration = units::as_units(1, "hours")
    ),
    "centre_col must have a crs specified"
  )

  # When centre_col is NULL, the first point of each track is used as the centre.
  test_no_centre <- track_summary_stats(
    x = test_tt_split,
    units_duration = units::as_units(1, "hours")
  )

  pts <- test_tt_split %>% dplyr::filter(trip_id == "id_1_trip_1")
  first_pt <- pts[1, ]
  expected_max <- max(
    sf::st_distance(pts$geometry, first_pt$geometry),
    na.rm = TRUE
  )

  observed_max <- test_no_centre %>%
    dplyr::filter(trip_id == "id_1_trip_1") %>%
    dplyr::pull(max_dist_centre)

  expect_equal(expected_max, observed_max)
})

# TODO add test for where there are >10 trips per individual (to make sure
# the trip_id field is carrying through the function correctly)
