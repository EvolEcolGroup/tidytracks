test_that("geom_event_path skips events without a location", {
  x <- example_tt
  sf::st_geometry(x)[3] <- sf::st_point()
  p <- ggplot2::ggplot() + geom_event_path(data = x)
  steps <- ggplot2::layer_data(p)
  # one step fewer per track, and one fewer for the event without a location
  expect_equal(nrow(steps), nrow(x) - 3L - 1L)
  # the step from the second event joins it to the fourth (the next located)
  expect_equal(
    sf::st_coordinates(steps$geometry[2])[, c("X", "Y")],
    sf::st_coordinates(sf::st_geometry(example_tt)[c(2, 4)]),
    ignore_attr = TRUE
  )
})
