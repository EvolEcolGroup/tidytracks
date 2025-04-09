test_that("dist_fast is equivalent to sf::dist",{
  # Create a data frame with coordinates
  coords <- data.frame(x = c(10, -21, 30), y = c(40, 5, -16))

  # Convert to sf object
  coords_sf <- sf::st_as_sf(coords, coords = c("x", "y"), crs = 4326)

  # Calculate distances using dist_fast
  dist_fast_result <- dist_fast(coords$x[1], coords$y[1], coords$x[2], coords$y[2])
  dist_fast_result <- as_units(dist_fast_result, "m") # Convert to meters for comparison

  # Calculate distances using sf::st_distance
  sf::sf_use_s2 (FALSE) # force the use of geodesic distances
  dist_sf_result <- sf::st_distance(coords_sf[1, ], coords_sf[2, ])

  # Check if the results are equal
  expect_equal(dist_fast_result, dist_sf_result[1,1])

})
