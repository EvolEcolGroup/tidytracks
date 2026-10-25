test_that("event_flag_thin_time gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    event_flag_thin_time(data.frame(a = 1:10), as_units(1, "h")),
    "x must be a move2 object"
  )
  expect_error(
    event_flag_thin_time(example_tt, interval = 3600),
    "`interval` must be a units object"
  )
  expect_error(
    event_flag_thin_time(example_tt, interval = as_units(1, "m")),
    "`interval` must carry time units"
  )
  expect_error(
    event_flag_thin_time(
      example_tt,
      interval = as_units(1, "h"),
      tolerance = 60
    ),
    "tolerance must be a units object"
  )
  expect_error(
    event_flag_thin_time(
      example_tt,
      interval = as_units(1, "h"),
      criterion = "other"
    )
  )
})

test_that("event_flag_thin_time matches move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  x <- tt_order_time(x)
  flag <- event_flag_thin_time(
    x,
    interval = as_units(30, "min"),
    tolerance = as_units(5, "min")
  )
  direct <- move2utils::mt_thin_time(x, interval = 1800, tolerance = 300)
  expect_type(flag, "logical")
  expect_identical(flag, direct$thin_selected)
  expect_true(any(flag) && !all(flag))
  # no interval between kept events is shorter than interval - tolerance
  # (intervals can be longer where thinning does not bridge a gap)
  lags <- as.numeric(
    move2::mt_time_lags(x[flag, ], units = "min")
  )
  lags <- lags[!is.na(lags)]
  expect_true(all(lags >= 25))
})

test_that("event_flag_thin_time passes tolerance and criterion", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  for (criterion in c("closest", "first")) {
    expect_identical(
      event_flag_thin_time(
        x,
        interval = as_units(1, "h"),
        tolerance = as_units(10, "min"),
        criterion = criterion
      ),
      move2utils::mt_thin_time(
        x,
        interval = 3600,
        tolerance = 600,
        criterion = criterion
      )$thin_selected
    )
  }
  # the default tolerance is interval / 10
  expect_identical(
    event_flag_thin_time(x, interval = as_units(1, "h")),
    move2utils::mt_thin_time(x, interval = 3600, tolerance = 360)$thin_selected
  )
})

test_that("event_flag_thin_time does not depend on the units of interval", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expect_identical(
    event_flag_thin_time(x, interval = as_units(30, "min")),
    event_flag_thin_time(x, interval = as_units(0.5, "h"))
  )
})

test_that("event_flag_thin_time returns flags in the order of the events", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  expected <- event_flag_thin_time(x, interval = as_units(30, "min"))
  shuffled <- rev(seq_len(nrow(x)))
  expect_identical(
    event_flag_thin_time(x[shuffled, ], interval = as_units(30, "min")),
    expected[shuffled]
  )
})

test_that("event_flag_thin_time never keeps events without a location", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  x_empty <- x
  sf::st_geometry(x_empty)[c(10, 20)] <- sf::st_point()
  flag <- event_flag_thin_time(x_empty, interval = as_units(30, "min"))
  expect_false(any(flag[c(10, 20)]))
  expect_identical(
    flag[-c(10, 20)],
    event_flag_thin_time(x[-c(10, 20), ], interval = as_units(30, "min"))
  )
})

test_that("tt_thin_time keeps the flagged events", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  thinned <- tt_thin_time(
    x,
    interval = as_units(30, "min"),
    tolerance = as_units(5, "min"),
    criterion = "first"
  )
  flag <- event_flag_thin_time(
    x,
    interval = as_units(30, "min"),
    tolerance = as_units(5, "min"),
    criterion = "first"
  )
  expect_s3_class(thinned, "move2")
  expect_identical(nrow(thinned), sum(flag))
  expect_identical(event_time(thinned), event_time(x)[flag])
})
