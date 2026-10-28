test_that("event_flag_corridor gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    event_flag_corridor(data.frame(a = 1:10)),
    "x must be a move2 object"
  )
  x <- example_tt
  sf::st_crs(x) <- NA
  expect_error(
    event_flag_corridor(x),
    "x must have a coordinate reference system"
  )
  expect_error(
    event_flag_corridor(example_tt, speed_threshold = 1),
    "speed_threshold must be a units object"
  )
  expect_error(
    event_flag_corridor(example_tt, speed_threshold = as_units(1, "m")),
    "speed_threshold must be a units object"
  )
  # vectors would be silently recycled along the steps by move2utils
  expect_error(
    event_flag_corridor(
      example_tt,
      speed_threshold = as_units(c(1, 2), "m/s")
    ),
    "must be single values"
  )
  expect_error(
    event_flag_corridor(example_tt, circvar_threshold = c(0.2, 0.5)),
    "must be single values"
  )
  expect_error(
    event_flag_corridor(example_tt[c(2, 1, 3:15), ]),
    "x must be ordered by time within each track; use tt_order_time"
  )
})

test_that("event_flag_corridor matches move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  corridor <- event_flag_corridor(
    x,
    speed_threshold = as_units(0.15, "m/s"),
    circvar_threshold = 0.2,
    min_segments = 2
  )
  direct <- move2utils::mt_corridor(
    x,
    speed_threshold = 0.15,
    circvar_threshold = 0.2,
    min_segments = 2
  )
  expect_type(corridor, "logical")
  expect_identical(corridor, direct$corridor == "corridor")
  expect_true(any(corridor))
  # the speed threshold can be given in any units of speed
  expect_identical(
    event_flag_corridor(
      x,
      speed_threshold = as_units(0.54, "km/h"),
      circvar_threshold = 0.2
    ),
    corridor
  )
})

test_that("event_flag_corridor warns when estimating thresholds", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  expect_warning(
    expect_warning(event_flag_corridor(x), "speed_threshold"),
    "circvar_threshold"
  )
})

test_that("event_flag_corridor gives NA for events without a location", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  x_empty <- x
  sf::st_geometry(x_empty)[c(10, 20)] <- sf::st_point()
  corridor <- event_flag_corridor(
    x_empty,
    speed_threshold = as_units(0.15, "m/s"),
    circvar_threshold = 0.2
  )
  expect_true(all(is.na(corridor[c(10, 20)])))
  expect_identical(
    corridor[-c(10, 20)],
    event_flag_corridor(
      x[-c(10, 20), ],
      speed_threshold = as_units(0.15, "m/s"),
      circvar_threshold = 0.2
    )
  )
})

test_that("event_flag_corridor requires coordinates in metres or degrees", {
  skip_if_not_installed("move2utils")
  # a projected CRS in US survey feet
  x <- sf::st_transform(create_spiky_tracks(), 2263)
  expect_error(
    event_flag_corridor(x),
    "x must have a geographic coordinate reference system, or a projected"
  )
})
