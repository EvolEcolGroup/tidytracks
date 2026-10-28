test_that("track_tot_distance gives the correct errors", {
  # try running it on an object that isn't a move2 object
  expect_error(
    track_tot_distance(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("track_tot_distance correctly computes track distance", {
  expect_equal(
    track_tot_distance(example_tt),
    as_units(c(a = 1170506.6, b = 870617.4, c = 812657.4), "m"),
    tolerance = 1e-6
  )
})

test_that("track_tot_distance correctly converts units", {
  distances_km <- track_tot_distance(example_tt, units = "km")
  expect_equal(
    units(distances_km)$numerator,
    "km"
  )
  expect_equal(
    unname(distances_km),
    as_units(c(1170.5066, 870.6174, 812.6574), "km"),
    tolerance = 1e-6
  )
  # same underlying quantity, regardless of the requested units
  expect_equal(
    distances_km,
    units::set_units(track_tot_distance(example_tt), "km")
  )
})

test_that("track_tot_distance skips events without a location", {
  # an event without a location does not break the track: the distance is
  # taken between the located events on either side
  x_empty <- example_tt
  sf::st_geometry(x_empty)[3] <- sf::st_point()
  expect_equal(
    track_tot_distance(x_empty),
    track_tot_distance(example_tt[-3, ])
  )
  # a track without any location has no distance
  sf::st_geometry(x_empty)[1:5] <- list(sf::st_point())
  expect_equal(
    track_tot_distance(x_empty),
    as_units(c(a = 0, b = 870617.4, c = 812657.4), "m"),
    tolerance = 1e-6
  )
})

test_that("track_tot_distance returns values in original order", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # example_tt_2 has tracks that first appear in the order b, a, c, which
  # differs from alphabetical order
  distances <- track_tot_distance(example_tt_2)
  expect_equal(names(distances), c("b", "a", "c"))
  expect_equal(
    unname(distances),
    as_units(c(1559776.1, 870617.4, 474273.1), "m"),
    tolerance = 1e-6
  )
})

test_that("track_tot_distance returns values in the order of the metadata", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # after ordering, the events are in the order a, b, c, whilst the metadata
  # is still in the order b, a, c
  example_tt_2 <- tt_order_time(example_tt_2)
  expect_equal(
    unique(as.character(event_track_id(example_tt_2))),
    c("a", "b", "c")
  )

  distances <- track_tot_distance(example_tt_2)
  expect_equal(names(distances), c("b", "a", "c"))
  expect_equal(
    unname(distances),
    as_units(c(1559776.1, 870617.4, 474273.1), "m"),
    tolerance = 1e-6
  )

  # so they can be added to the metadata
  show_meta(example_tt_2)$tot_distance <- track_tot_distance(example_tt_2)
  expect_equal(
    show_meta(example_tt_2)$tot_distance[
      show_meta(example_tt_2)$track_id == "a"
    ],
    as_units(870617.4, "m"),
    tolerance = 1e-6
  )
})
