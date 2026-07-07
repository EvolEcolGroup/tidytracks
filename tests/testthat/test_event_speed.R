# tests/testthat/test-event_speed.R

test_that("event_speed matches move2::mt_speed for geographic coordinates", {
  sf::sf_use_s2(FALSE) # force the use of geodesic distances
  
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
  
  expect_equal(
    event_speed(example_tt, units = as_units("km/h")),
    move2::mt_speed(example_tt, units = "km/h"),
    tolerance = 1e-8
  )
})

test_that("event_speed matches move2::mt_speed for projected coordinates with custom units", {
  
  x_proj <- sf::st_transform(example_tt, 3857)
  
  expect_equal(
    event_speed(x_proj, units = as_units("km/h")),
    move2::mt_speed(x_proj, units = "km/h"),
    tolerance = 1e-8
  )
})

# test error messages
test_that("event_speed gives error for non-move2 objects", {
  expect_error(event_speed(data.frame(x = 1:5, y = 1:5)),
               "x must be a move2 object")
})

test_that("event_speed gives error for non-units objects", {
  expect_error(event_speed(example_tt, units = "m/s"), 
               "units must be a units object")
})
