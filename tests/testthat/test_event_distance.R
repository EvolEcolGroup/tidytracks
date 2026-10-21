test_that("event_distance gives error for objects without a CRS", {
  expect_error(
    event_distance(sf::st_set_crs(example_tt, NA)),
    "x must have a coordinate reference system"
  )
})
