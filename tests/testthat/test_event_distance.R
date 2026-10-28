test_that("event_distance gives error for objects without a CRS", {
  expect_error(
    event_distance(sf::st_set_crs(example_tt, NA)),
    "x must have a coordinate reference system"
  )
})

test_that("event_distance requires units as a units object", {
  expect_equal(
    event_distance(example_tt, units = as_units("km")),
    units::set_units(event_distance(example_tt), "km")
  )
  expect_error(
    event_distance(example_tt, units = NULL),
    "units must be a units object"
  )
  expect_error(
    event_distance(example_tt, units = "km"),
    "units must be a units object"
  )
})

test_that("event_distance returns one value per event without events", {
  expect_length(event_distance(example_tt[0, ]), 0)
  # a single event has no segment
  expect_equal(event_distance(example_tt[1, ]), as_units(NA_real_, "m"))
})
