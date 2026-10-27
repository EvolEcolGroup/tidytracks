# the s2 setting at the start of this file, to check that the tests restore it
s2_at_start <- sf::sf_use_s2()

# move2::mt_speed() uses geodesic distances, as event_speed() does, only when
# s2 is switched off; tests with geographic coordinates switch it off, and
# restore the previous setting (which applies to the whole session) on exit

test_that("event_speed matches move2::mt_speed for geographic coordinates", {
  old_s2 <- suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  expect_equal(
    event_speed(example_tt, units = as_units("m/min")),
    move2::mt_speed(example_tt),
    tolerance = 1e-8
  )
})

test_that("event_speed matches move2::mt_speed for projected coordinates", {
  x_proj <- sf::st_transform(example_tt, 3857)

  expect_equal(
    event_speed(x_proj),
    move2::mt_speed(x_proj),
    tolerance = 1e-8
  )
})

test_that("event_speed matches move2::mt_speed with custom units", {
  old_s2 <- suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)

  expect_equal(
    event_speed(example_tt, units = as_units("km/h")),
    move2::mt_speed(example_tt, units = "km/h"),
    tolerance = 1e-8
  )
})

test_that("event_speed matches mt_speed with projected custom units", {
  x_proj <- sf::st_transform(example_tt, 3857)

  expect_equal(
    event_speed(x_proj, units = as_units("km/h")),
    move2::mt_speed(x_proj, units = "km/h"),
    tolerance = 1e-8
  )
})

# test error messages
test_that("event_speed gives error for non-move2 objects", {
  expect_error(
    event_speed(data.frame(x = 1:5, y = 1:5)),
    "x must be a move2 object"
  )
})

test_that("event_speed gives error for non-units objects", {
  expect_error(
    event_speed(example_tt, units = "m/s"),
    "units must be a units object"
  )
  expect_error(
    event_speed(example_tt, units = NULL),
    "units must be a units object"
  )
})

test_that("event_speed gives error for objects without a CRS", {
  expect_error(
    event_speed(sf::st_set_crs(example_tt, NA)),
    "x must have a coordinate reference system"
  )
})

test_that("the event_speed tests restore the s2 setting", {
  expect_identical(sf::sf_use_s2(), s2_at_start)
})
