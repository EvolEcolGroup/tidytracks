test_that("sf_point_col creates valid point geometry column", {
  pts <- sf_point_col(c(1, 2, 3), c(4, 5, 6))
  expect_true(inherits(pts, "sfc"))
  expect_equal(length(pts), 3)
  expect_true(all(sf::st_geometry_type(pts) == "POINT"))
})

test_that("sf_point_col errors on mismatched x and y lengths", {
  expect_error(
    sf_point_col(c(1, 2, 3), c(4, 5)),
    "x and y must have the same length"
  )
})

test_that("sf_point_col assigns CRS when provided", {
  pts <- sf_point_col(c(0, 1), c(0, 1), crs = 4326)
  expect_equal(sf::st_crs(pts)$epsg, 4326)
})
