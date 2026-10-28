test_that("event_azimuth returns degrees by default", {
  skip_if_not_installed("lwgeom")
  azimuth <- event_azimuth(example_tt)
  expect_equal(units(azimuth), units(as_units("degrees")))
  expect_equal(
    azimuth,
    units::set_units(event_azimuth(example_tt, units = "radians"), "degrees")
  )
})
