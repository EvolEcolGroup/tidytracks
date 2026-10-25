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
