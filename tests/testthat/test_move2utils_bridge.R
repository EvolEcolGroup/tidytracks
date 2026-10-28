# a stand-in for a move2utils function: it records its arguments, checks that
# it only receives events with a location, and returns its input with added
# columns
fake_move2utils_fn <- function(x, plot = TRUE, silent = FALSE) {
  stopifnot(!any(sf::st_is_empty(x)))
  x$plot_arg <- plot
  x$silent_arg <- silent
  x$time_copy <- move2::mt_time(x)
  x
}

test_that("check_move2utils gives an informative error", {
  local_mocked_bindings(is_move2utils_installed = function() FALSE)
  expect_error(
    check_move2utils("my_fun"),
    "my_fun\\(\\) requires the suggested package 'move2utils'"
  )
})

test_that("move2utils_args turns off plots and narration by default", {
  expect_identical(
    move2utils_args(fake_move2utils_fn, list(1)),
    list(1, plot = FALSE, silent = TRUE)
  )
  # values set by the caller are kept
  expect_identical(
    move2utils_args(fake_move2utils_fn, list(1, plot = TRUE)),
    list(1, plot = TRUE, silent = TRUE)
  )
  # arguments are not added to functions that do not have them
  expect_identical(
    move2utils_args(function(x) x, list(1)),
    list(1)
  )
  # names are matched exactly: an argument whose name starts with "plot" does
  # not count as plot
  expect_identical(
    move2utils_args(fake_move2utils_fn, list(1, plot_type = "a")),
    list(1, plot_type = "a", plot = FALSE, silent = TRUE)
  )
})

test_that("check_time_ordered requires events ordered by time", {
  expect_null(check_time_ordered(example_tt))
  # times not in order within a track
  expect_error(
    check_time_ordered(example_tt[c(2, 1, 3:15), ]),
    "x must be ordered by time within each track; use tt_order_time"
  )
  # events of a track not stored together
  expect_error(
    check_time_ordered(example_tt[c(1:3, 6:8, 4:5, 9:15), ]),
    "x must be ordered by time within each track; use tt_order_time"
  )
  # duplicated times are allowed
  expect_null(check_time_ordered(example_tt[c(1, 1:15), ]))
})

test_that("check_metric_crs requires coordinates in metres or degrees", {
  expect_null(check_metric_crs(example_tt))
  expect_null(check_metric_crs(sf::st_transform(example_tt, 32630)))
  # US survey feet, which move2utils would take to be metres
  expect_error(
    check_metric_crs(sf::st_transform(example_tt, 2263)),
    "x must have a geographic coordinate reference system, or a projected"
  )
})

test_that("call_move2utils matches the results to the original events", {
  x <- example_tt
  sf::st_geometry(x)[2] <- sf::st_point()

  res <- call_move2utils(
    x,
    fake_move2utils_fn,
    cols = c("time_copy", "plot_arg", "silent_arg")
  )
  expect_s3_class(res, "tbl_df")
  expect_identical(names(res), c("time_copy", "plot_arg", "silent_arg"))
  expect_identical(nrow(res), nrow(x))
  expect_equal(res$time_copy[-2], event_time(x)[-2])
  # the event without a location gets NA
  expect_true(all(is.na(res[2, ])))
  # plots and narration are turned off
  expect_true(all(!res$plot_arg[-2]))
  expect_true(all(res$silent_arg[-2]))
})

test_that("call_move2utils checks that events are ordered by time", {
  x <- example_tt[c(5, 3, 1, 2, 4, 6:15), ]
  expect_error(
    call_move2utils(x, fake_move2utils_fn, cols = "time_copy"),
    "x must be ordered by time within each track"
  )
  # unless the move2utils function does not need it
  res <- call_move2utils(
    x,
    function(x) {
      x$time_copy <- move2::mt_time(x)
      x
    },
    cols = "time_copy",
    time_ordered = FALSE
  )
  expect_equal(res$time_copy, event_time(x))
})

test_that("call_move2utils passes further arguments", {
  res <- call_move2utils(
    example_tt,
    fake_move2utils_fn,
    plot = TRUE,
    cols = "plot_arg"
  )
  expect_true(all(res$plot_arg))
})

test_that("call_move2utils checks the output of move2utils", {
  expect_error(
    call_move2utils(example_tt, function(x) x[-1, ], cols = "time"),
    "did not return one row for each event"
  )
  expect_error(
    call_move2utils(example_tt, function(x) x[rev(seq_len(nrow(x))), ],
      cols = "time"
    ),
    "did not return one row for each event"
  )
  expect_error(
    call_move2utils(example_tt, function(x) x, cols = "not_there"),
    "did not return the column\\(s\\): not_there"
  )
})

test_that("move2utils_args always sets remove to FALSE", {
  fn <- function(x, remove = TRUE) x
  expect_identical(move2utils_args(fn, list(1)), list(1, remove = FALSE))
  expect_identical(
    move2utils_args(fn, list(1, remove = TRUE)),
    list(1, remove = FALSE)
  )
})

test_that("units_to_move2utils converts physical arguments", {
  converted <- units_to_move2utils(list(
    v_max = as_units(36, "km/h"),
    location_error = as_units(0.02, "km"),
    mass = as_units(500, "g"),
    min_leg = NULL,
    threshold = 3,
    method = "a"
  ))
  expect_identical(
    converted,
    list(
      v_max = 10, location_error = 20, mass = 0.5, min_leg = NULL,
      threshold = 3, method = "a"
    )
  )
  # a column name can be given for location_error
  expect_identical(
    units_to_move2utils(list(location_error = "error_col")),
    list(location_error = "error_col")
  )
})

test_that("units_to_move2utils requires units for physical arguments", {
  expect_error(
    units_to_move2utils(list(v_max = 10)),
    "v_max must be a units object with units convertible to m/s"
  )
  expect_error(
    units_to_move2utils(list(jitter = as_units(1, "s"))),
    "jitter must be a units object with units convertible to m"
  )
  # units are not converted for arguments with unknown units (e.g. times,
  # which move2utils takes in seconds or in minutes depending on the function)
  expect_error(
    units_to_move2utils(list(time_step = as_units(1, "min"))),
    "units objects are not supported for the argument 'time_step'"
  )
  expect_error(
    units_to_move2utils(list(as_units(1, "m"))),
    "units objects are not supported"
  )
})

test_that("apply_flag_action acts on the flagged events", {
  x <- example_tt
  valid <- rep(TRUE, nrow(x))
  valid[c(2, 9)] <- FALSE

  removed <- apply_flag_action(x, valid, "remove")
  expect_identical(event_time(removed), event_time(x)[valid])

  nulled <- apply_flag_action(x, valid, "null")
  expect_identical(nrow(nulled), nrow(x))
  expect_identical(sf::st_is_empty(nulled), !valid)
  expect_equal(sf::st_geometry(nulled)[valid], sf::st_geometry(x)[valid])

  interpolated <- apply_flag_action(x, valid, "interpolate")
  expect_identical(nrow(interpolated), nrow(x))
  expect_false(any(sf::st_is_empty(interpolated)))
  expect_equal(
    sf::st_geometry(interpolated)[valid],
    sf::st_geometry(x)[valid]
  )
})
