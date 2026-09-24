test_that("tt_split_trips accepts one centre per track", {
  # create the toy dataframe of longitude, latitude, date_time, bird_id
  coords_df <- create_toy_df()

  # convert to a tidytracks object
  test_mt <- tt_read_data(
    events = coords_df,
    col_track_id = "bird_id",
    col_coords = c("longitude", "latitude"),
    col_date_time = "date_time"
  )
  show_meta(test_mt)$centre_sf <- sf_point_col(
    x = c(0, 0),
    y = c(0, 0),
    crs = 4326
  )

  # now test the trip splitting

  # measure distances from point 0,0
  coords <- sf::st_coordinates(test_mt)
  centre_dist <- geodist::geodist(
    x = coords,
    y = data.frame(lon = 0, lat = 0),
    measure = "geodesic"
  ) /
    1000
  # points at the colony
  at_centre <- centre_dist < 100

  # split the trips using centre_sf
  test_mt_split <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )

  # check that the trip ids are correct
  expected_trip_id_field <- c(
    "id_1_trip_na",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_1",
    "id_1_trip_na",
    "id_1_trip_2",
    "id_1_trip_2",
    "id_1_trip_2",
    "id_1_trip_2",
    "id_1_trip_2",
    "id_1_trip_na",
    "id_1_trip_na",
    "id_1_trip_3",
    "id_1_trip_3",
    "id_1_trip_3",
    "id_1_trip_3",
    "id_2_trip_na",
    "id_2_trip_na",
    "id_2_trip_1",
    "id_2_trip_1",
    "id_2_trip_1",
    "id_2_trip_1"
  )
  expect_identical(test_mt_split$trip_id, expected_trip_id_field)
  expect_equal(length(unique(test_mt_split$trip_id)), 6)
  expect_equal(length(unique(test_mt_split$bird_id)), 2)

  # the first trip is from 2 to 12
  expect_true(
    all(
      range(
        which(
          test_mt_split$trip_id == "id_1_trip_1"
        )
      ) ==
        c(2, 12)
    )
  )
  # detect correctly time at colony
  expect_true(
    all(
      test_mt_split$trip_id[at_centre] %in%
        c("id_1_trip_na", "id_2_trip_na")
    )
  )
  # the last trip of id_1 is incomplete
  expect_true(
    (show_meta(test_mt_split) %>%
       dplyr::filter(trip_id == "id_1_trip_3"))$trip_type ==
      "incomplete"
  )

  # repeat with different units
  test_mt_split2 <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100000, "m"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  expect_identical(test_mt_split, test_mt_split2)

  # check if the centers have different projection
  show_meta(test_mt)$centre_sf <-
    sf::st_transform(show_meta(test_mt)$centre_sf, 5936)

  # repeat with different units
  test_mt_split2b <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100000, "m"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  expect_identical(test_mt_split$trip_id, test_mt_split2b$trip_id)

  # change inbound buffer
  test_mt_split3 <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = FALSE
  )
  # the last trip of id_1 is incomplete
  expect_true(
    (show_meta(test_mt_split3) %>%
       dplyr::filter(trip_id == "id_1_trip_3"))$trip_type ==
      "complete"
  )

  # check that, if we say complete = TRUE, all trips are complete
  test_mt_split4 <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = TRUE
  )
  # all trips should be complete
  expect_true(all((show_meta(test_mt_split4)$trip_type == "complete")))
  # there should only be 4 lines (3 trips + 1 trip)
  expect_equal(nrow(show_meta(test_mt_split4)), 4)

  # now test some errors for the centre_col argument
  expect_error(
    tt_split_trips(
      test_mt,
      centre_col = "non_existent_column",
      buffer_outbound = as_units(100, "km"),
      buffer_inbound = as_units(100, "km"),
      complete = FALSE
    ),
    "centre_col must be a column name in the metadata table"
  )
  expect_error(
    tt_split_trips(
      test_mt,
      centre_col = "bird_id",
      buffer_outbound = as_units(100, "km"),
      buffer_inbound = as_units(100, "km"),
      complete = FALSE
    ),
    "centre_col must be a `sfc_POINT` column in the metadata table"
  )

  # Remove the CRS from center_sf and check that the expected error is raised.
  show_meta(test_mt)$centre_sf <- sf_point_col(x = c(0, 0), y = c(0, 0))
  expect_error(
    tt_split_trips(
      test_mt,
      centre_col = "centre_sf",
      buffer_outbound = as_units(100, "km"),
      buffer_inbound = as_units(100, "km"),
      complete = FALSE
    ),
    "centre_col must have a crs specified"
  )
})

test_that("tt_split_trips marks trips starting outside incomplete", {
  # Create a track that starts far from the colony (outside the buffer) and
  # returns to the colony at the end. Without checking the start, this trip
  # would be falsely classified as "complete".
  coords_df <- data.frame(
    longitude = c(5, 4, 3, 2, 1, 0.1),
    latitude = c(0, 0, 0, 0, 0, 0),
    date_time = seq(
      from = as.POSIXct("2020-01-01 00:00:00"),
      by = "1 hour",
      length.out = 6
    ),
    bird_id = "id_1"
  )

  test_mt <- tt_read_data(
    events = coords_df,
    col_track_id = "bird_id",
    col_coords = c("longitude", "latitude"),
    col_date_time = "date_time"
  )
  show_meta(test_mt)$centre_sf <- sf_point_col(x = 0, y = 0, crs = 4326)

  # Split trips: animal is outside 100 km from colony for first 5 points and
  # returns within 100 km on the last point.
  result <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )

  # There should be one trip (trip_1) plus one at_centre segment at the end
  meta <- show_meta(result)
  expect_true("id_1_trip_1" %in% meta$trip_id)

  # The trip that started outside the colony must be classified as incomplete
  expect_equal(
    meta$trip_type[meta$trip_id == "id_1_trip_1"],
    "incomplete"
  )

  # With complete = TRUE, no trips should remain (the only trip is incomplete)
  result_complete <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = TRUE
  )
  expect_equal(nrow(show_meta(result_complete)), 0)
})

# @TODO write tests with centre inputs as different from each others
