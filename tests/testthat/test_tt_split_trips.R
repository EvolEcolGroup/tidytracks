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

  show_meta(test_mt)$centre_sf <- sf::st_sfc(
    sf::st_point(),
    sf::st_point(c(0, 0)),
    crs = 4326
  )
  expect_error(
    tt_split_trips(
      test_mt,
      centre_col = "centre_sf",
      buffer_outbound = as_units(100, "km"),
      buffer_inbound = as_units(100, "km"),
      complete = FALSE
    ),
    "centre_col must not contain empty geometries"
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


test_that("tt_split_trips pairs each track with its own centre", {
  # each bird makes one trip from its own nest; the nests are 50 degrees apart
  coords_df <- data.frame(
    bird_id = rep(c("b", "a"), each = 5),
    longitude = c(0, 0.5, 1, 0.5, 0, 50, 50.5, 51, 50.5, 50),
    latitude = 0,
    date_time = as.POSIXct("2020-01-01", tz = "UTC") + rep(0:4, 2) * 3600
  )
  test_mt <- move2::mt_as_move2(
    sf::st_as_sf(coords_df, coords = c("longitude", "latitude"), crs = 4326),
    time_column = "date_time",
    track_id_column = "bird_id"
  )
  show_meta(test_mt)$centre_sf <- sf_point_col(
    x = ifelse(show_meta(test_mt)$bird_id == "b", 0, 50),
    y = c(0, 0),
    crs = 4326
  )
  # reorder the events so that they are no longer in the same track order as
  # the metadata
  test_mt <- tt_order_time(test_mt)
  expect_false(identical(
    unique(as.character(event_track_id(test_mt))),
    as.character(show_meta(test_mt)$bird_id)
  ))

  result <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(10, "km"),
    buffer_inbound = as_units(10, "km"),
    complete = FALSE
  )
  expect_identical(
    result$trip_id,
    paste0(
      rep(c("a", "b"), each = 5),
      c("_trip_na", "_trip_1", "_trip_1", "_trip_1", "_trip_na")
    )
  )
  meta <- show_meta(result)
  expect_equal(
    meta$trip_type[meta$trip_id %in% c("a_trip_1", "b_trip_1")],
    c("complete", "complete")
  )
})

test_that("tt_split_trips labels events that are not grouped or sorted", {
  centre <- sf_point_col(x = c(0, 0), y = c(0, 0), crs = 4326)
  make_tracks <- function(coords_df) {
    test_mt <- move2::mt_as_move2(
      sf::st_as_sf(coords_df, coords = c("longitude", "latitude"), crs = 4326),
      time_column = "date_time",
      track_id_column = "bird_id"
    )
    show_meta(test_mt)$centre_sf <- centre[seq_len(nrow(show_meta(test_mt)))]
    test_mt
  }
  split_trips <- function(test_mt) {
    tt_split_trips(
      test_mt,
      centre_col = "centre_sf",
      buffer_outbound = as_units(10, "km"),
      buffer_inbound = as_units(10, "km"),
      complete = FALSE
    )$trip_id
  }
  trip_pattern <- c("_trip_na", "_trip_1", "_trip_1", "_trip_1", "_trip_na")

  # events of two tracks interleaved in time order
  interleaved <- data.frame(
    bird_id = rep(c("a", "b"), 5),
    longitude = rep(c(0, 0.5, 1, 0.5, 0), each = 2),
    latitude = rep(c(0, 0.01), 5),
    date_time = as.POSIXct("2020-01-01", tz = "UTC") + rep(0:4, each = 2) * 3600
  )
  expect_identical(
    split_trips(make_tracks(interleaved)),
    paste0(rep(c("a", "b"), 5), rep(trip_pattern, each = 2))
  )

  # events of one track that are not in time order
  shuffled <- data.frame(
    bird_id = "a",
    longitude = c(0, 0.5, 1, 0.5, 0),
    latitude = 0,
    date_time = as.POSIXct("2020-01-01", tz = "UTC") + (0:4) * 3600
  )[c(1, 3, 2, 5, 4), ]
  expect_identical(
    split_trips(make_tracks(shuffled)),
    paste0("a", trip_pattern[c(1, 3, 2, 5, 4)])
  )
})

test_that("tt_split_trips handles events without a location", {
  coords_df <- data.frame(
    bird_id = "a",
    longitude = c(0.5, 0, 0.5, 1, 0.5, 0, 0.5),
    latitude = 0,
    date_time = as.POSIXct("2020-01-01", tz = "UTC") + (0:6) * 3600
  )
  test_mt <- move2::mt_as_move2(
    sf::st_as_sf(coords_df, coords = c("longitude", "latitude"), crs = 4326),
    time_column = "date_time",
    track_id_column = "bird_id"
  )
  show_meta(test_mt)$centre_sf <- sf_point_col(x = 0, y = 0, crs = 4326)
  # remove the first location (before the bird is first seen at the nest),
  # one during the trip and the last one (after the bird is back at the nest)
  sf::st_geometry(test_mt)[c(1, 4, 7)] <- sf::st_point()

  result <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(10, "km"),
    buffer_inbound = as_units(10, "km"),
    complete = FALSE
  )
  expect_identical(
    result$trip_id,
    paste0("a", c(rep("_trip_na", 2), rep("_trip_1", 3), rep("_trip_na", 2)))
  )
  meta <- show_meta(result)
  expect_equal(meta$trip_type[meta$trip_id == "a_trip_1"], "complete")
})

test_that("tt_split_trips marks the last trip, not the centre, incomplete", {
  # the inbound buffer is smaller than the outbound one, and both tracks end
  # 5 km from the nest: "a" never leaves the outbound buffer, and "b" starts
  # with a trip and then stays within the outbound buffer
  coords_df <- data.frame(
    bird_id = rep(c("a", "b"), each = 4),
    longitude = c(0, 0.01, 0.03, 0.045, 0.5, 0.3, 0.045, 0.045),
    latitude = 0,
    date_time = as.POSIXct("2020-01-01", tz = "UTC") + rep(0:3, 2) * 3600
  )
  test_mt <- move2::mt_as_move2(
    sf::st_as_sf(coords_df, coords = c("longitude", "latitude"), crs = 4326),
    time_column = "date_time",
    track_id_column = "bird_id"
  )
  show_meta(test_mt)$centre_sf <- sf_point_col(
    x = c(0, 0),
    y = c(0, 0),
    crs = 4326
  )

  result <- tt_split_trips(
    test_mt,
    centre_col = "centre_sf",
    buffer_outbound = as_units(10, "km"),
    buffer_inbound = as_units(1, "km"),
    complete = FALSE
  )
  meta <- show_meta(result)
  expect_identical(meta$trip_id, c("a_trip_na", "b_trip_1", "b_trip_na"))
  expect_identical(meta$trip_type, c("at_centre", "incomplete", "at_centre"))
})
