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

test_that("geom_event_path maps and facets by columns of the metadata", {
  # sex is in the metadata only
  expect_false("sex" %in% names(example_tt))
  p <- ggplot2::ggplot() +
    geom_event_path(data = example_tt, ggplot2::aes(color = sex)) +
    ggplot2::facet_wrap(~sex)
  steps <- ggplot2::layer_data(p)
  # two colours and two panels, one per sex (tracks a and b are males)
  expect_equal(length(unique(steps$colour)), 2L)
  expect_equal(length(unique(steps$PANEL)), 2L)
  # the steps of each track are in the panel of its sex (one step fewer than
  # events per track)
  expect_equal(as.vector(table(steps$PANEL)), c(5L - 1L, 10L - 2L))
  # the object of the user is not changed
  expect_false("sex" %in% names(example_tt))
})

test_that("geom_event_point maps and facets by columns of the metadata", {
  x <- example_tt
  # a location in the metadata is not added to the events of the layer
  show_meta(x)$nest <- sf_point_col(
    x = show_meta(x)$nest_lon,
    y = show_meta(x)$nest_lat,
    crs = 4326
  )
  p <- ggplot2::ggplot() +
    geom_event_point(data = x, ggplot2::aes(color = sex)) +
    ggplot2::facet_wrap(~sex)
  points <- ggplot2::layer_data(p)
  expect_equal(length(unique(points$colour)), 2L)
  expect_equal(as.vector(table(points$PANEL)), c(5L, 10L))
  layer_data <- p$layers[[1]]$data
  expect_true(all(c("sex", "nest_lon", "nest_lat") %in% names(layer_data)))
  expect_false("nest" %in% names(layer_data))
  # the geometry of the layer is that of the events
  expect_equal(attr(layer_data, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(layer_data), sf::st_coordinates(x))
})

test_that("the geom_event_* functions work with an sf table of metadata", {
  # an sf table of metadata, set without show_meta<- (which would turn it
  # into a plain table), with its geometry named as that of the events
  meta_sf <- sf::st_as_sf(
    show_meta(example_tt),
    coords = c("nest_lon", "nest_lat"),
    crs = 4326,
    remove = FALSE
  )
  x <- move2::mt_set_track_data(example_tt, meta_sf)
  expect_message(
    p <- ggplot2::ggplot() +
      geom_event_point(data = x, ggplot2::aes(color = sex)),
    "renamed 'geometry.meta'"
  )
  layer_data <- p$layers[[1]]$data
  expect_true("sex" %in% names(layer_data))
  expect_false("geometry.meta" %in% names(layer_data))
  expect_equal(attr(layer_data, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(layer_data), sf::st_coordinates(x))
  # and so does geom_event_path()
  expect_message(
    p <- ggplot2::ggplot() +
      geom_event_path(data = x, ggplot2::aes(color = sex)),
    "renamed 'geometry.meta'"
  )
  expect_true("sex" %in% names(p$layers[[1]]$data))
})
