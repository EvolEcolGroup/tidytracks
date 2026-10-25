test_that("event_flag_thin_distance gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    event_flag_thin_distance(data.frame(a = 1:10), as_units(1, "km")),
    "x must be a move2 object"
  )
  x <- example_tt
  sf::st_crs(x) <- NA
  expect_error(
    event_flag_thin_distance(x, as_units(1, "km")),
    "x must have a coordinate reference system"
  )
  expect_error(
    event_flag_thin_distance(example_tt, distance = 1000),
    "distance must be a units object"
  )
  expect_error(
    event_flag_thin_distance(example_tt, distance = as_units(1, "h")),
    "distance must have units of length"
  )
  expect_error(
    event_flag_thin_distance(example_tt, distance = as_units(0, "m")),
    "distance must be a positive distance"
  )
  expect_error(
    event_flag_thin_distance(
      example_tt,
      distance = as_units(1, "km"),
      tolerance = 100,
      method = "interval"
    ),
    "tolerance must be a units object"
  )
  expect_error(
    event_flag_thin_distance(
      example_tt,
      distance = as_units(1, "km"),
      method = "other"
    )
  )
})

test_that("event_flag_thin_distance matches move2utils", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  flag <- event_flag_thin_distance(x, distance = as_units(1, "km"))
  direct <- move2utils::mt_thin_distance(x, distance = 1000)
  expect_type(flag, "logical")
  expect_identical(flag, direct$thin_selected)
  expect_true(any(flag) && !all(flag))
  # the first event of each track is kept
  expect_true(all(flag[!duplicated(as.character(event_track_id(x)))]))

  flag_interval <- event_flag_thin_distance(
    x,
    distance = as_units(1, "km"),
    tolerance = as_units(200, "m"),
    method = "interval",
    criterion = "first"
  )
  expect_identical(
    flag_interval,
    move2utils::mt_thin_distance(
      x,
      distance = 1000,
      tolerance = 200,
      method = "interval",
      criterion = "first"
    )$thin_selected
  )
})

test_that("event_flag_thin_distance does not depend on the units", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expect_identical(
    event_flag_thin_distance(
      x,
      distance = as_units(1, "km"),
      tolerance = as_units(0.2, "km"),
      method = "interval"
    ),
    event_flag_thin_distance(
      x,
      distance = as_units(1000, "m"),
      tolerance = as_units(200, "m"),
      method = "interval"
    )
  )
})

test_that("event_flag_thin_distance warns about an unused tolerance", {
  skip_if_not_installed("move2utils")
  expect_warning(
    event_flag_thin_distance(
      example_tt,
      distance = as_units(200, "km"),
      tolerance = as_units(10, "km")
    ),
    "tolerance"
  )
})

test_that("event_flag_thin_distance requires events ordered by time", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  expect_error(
    event_flag_thin_distance(
      x[rev(seq_len(nrow(x))), ],
      distance = as_units(1, "km")
    ),
    "x must be ordered by time within each track; use tt_order_time"
  )
})

test_that("event_flag_thin_distance ignores events without a location", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  x_empty <- x
  sf::st_geometry(x_empty)[c(10, 20)] <- sf::st_point()
  flag <- event_flag_thin_distance(x_empty, distance = as_units(1, "km"))
  expect_false(any(flag[c(10, 20)]))
  expect_identical(
    flag[-c(10, 20)],
    event_flag_thin_distance(x[-c(10, 20), ], distance = as_units(1, "km"))
  )
})

test_that("tt_thin_distance keeps the flagged events", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  thinned <- tt_thin_distance(
    x,
    distance = as_units(1, "km"),
    tolerance = as_units(200, "m"),
    method = "interval"
  )
  flag <- event_flag_thin_distance(
    x,
    distance = as_units(1, "km"),
    tolerance = as_units(200, "m"),
    method = "interval"
  )
  expect_s3_class(thinned, "move2")
  expect_identical(nrow(thinned), sum(flag))
  expect_identical(event_time(thinned), event_time(x)[flag])
})
