test_that("event_azimuth returns degrees by default", {
  skip_if_not_installed("lwgeom")
  azimuth <- event_azimuth(example_tt)
  expect_equal(units(azimuth), units(as_units("degrees")))
  expect_equal(
    azimuth,
    units::set_units(event_azimuth(example_tt, units = "radians"), "degrees")
  )
})

test_that("event_azimuth gives NA for events without a location", {
  skip_if_not_installed("lwgeom")
  # as event_distance(), NA for the segments to and from the third event
  x_empty <- example_tt
  sf::st_geometry(x_empty)[3] <- sf::st_point()
  azimuth <- event_azimuth(example_tt)
  azimuth[2:3] <- NA
  expect_equal(event_azimuth(x_empty), azimuth)
  # and only NA without any location
  sf::st_geometry(x_empty)[] <- list(sf::st_point())
  expect_equal(
    event_azimuth(x_empty),
    as_units(rep(NA_real_, nrow(x_empty)), "degrees")
  )
})
