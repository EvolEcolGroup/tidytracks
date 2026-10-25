test_that("track_suggest_max_speed gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    track_suggest_max_speed(data.frame(a = 1:10)),
    "x must be a move2 object"
  )
  expect_error(
    track_suggest_max_speed(example_tt, units = "km/h"),
    "units must be a units object"
  )
  x <- example_tt
  sf::st_crs(x) <- NA
  expect_error(
    track_suggest_max_speed(x),
    "x must have a coordinate reference system"
  )
  expect_error(track_suggest_max_speed(example_tt, method = "other"))
})

test_that("track_suggest_max_speed applies move2utils to each track", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  suggested <- track_suggest_max_speed(x)
  expect_s3_class(suggested, "units")
  expect_identical(units::deparse_unit(suggested), "m s-1")
  expect_identical(names(suggested), c("a", "b"))
  direct <- vapply(c("a", "b"), function(id) {
    move2utils::mt_suggest_speed_cap(
      x[event_track_id(x) == id, ],
      plot = FALSE,
      silent = TRUE
    )
  }, numeric(1))
  expect_true(all(is.finite(direct)))
  expect_equal(as.numeric(suggested), unname(direct))
  # the suggestion of each track differs from the one pooling the tracks
  pooled <- move2utils::mt_suggest_speed_cap(x, plot = FALSE, silent = TRUE)
  expect_false(isTRUE(all.equal(as.numeric(suggested), rep(pooled, 2))))
})

test_that("track_suggest_max_speed returns the requested units", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  expect_equal(
    track_suggest_max_speed(x, units = as_units("km/h")),
    units::set_units(track_suggest_max_speed(x), "km/h")
  )
})

test_that("track_suggest_max_speed passes method and threshold", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  x_a <- x[event_track_id(x) == "a", ]
  expect_equal(
    as.numeric(track_suggest_max_speed(x_a, method = "gap", threshold = 2)),
    move2utils::mt_suggest_speed_cap(
      x_a,
      method = "gap",
      threshold = 2,
      plot = FALSE,
      silent = TRUE
    )
  )
})

test_that("track_suggest_max_speed gives NA when no break is found", {
  skip_if_not_installed("move2utils")
  # too few steps to look for a break
  suggested <- track_suggest_max_speed(example_tt)
  expect_identical(names(suggested), c("a", "b", "c"))
  expect_true(all(is.na(suggested)))
})

test_that("track_suggest_max_speed returns tracks in metadata order", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  expected <- track_suggest_max_speed(x)
  # reverse the order of the events, so that track b comes first
  x_rev <- x[rev(seq_len(nrow(x))), ]
  expect_identical(
    unique(as.character(event_track_id(x_rev))),
    c("b", "a")
  )
  expect_equal(track_suggest_max_speed(x_rev), expected)
})

test_that("track_suggest_max_speed ignores events without a location", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  # remove the location of the first event of track a
  x_empty <- x
  sf::st_geometry(x_empty)[1] <- sf::st_point()
  expect_equal(
    track_suggest_max_speed(x_empty),
    track_suggest_max_speed(x[-1, ])
  )
  # a track with no located events gets NA
  sf::st_geometry(x_empty)[event_track_id(x_empty) == "b"] <- sf::st_point()
  suggested <- track_suggest_max_speed(x_empty)
  expect_identical(names(suggested), c("a", "b"))
  expect_true(is.na(suggested[["b"]]))
})
