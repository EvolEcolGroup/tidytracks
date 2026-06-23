
# -----------------------------------------------------------------------------
# Test helper
# -----------------------------------------------------------------------------
# Minimal move2 constructor for tests, following the structure of the toy
# example used in the discussion.
#
# We use a projected CRS (EPSG:3857), so the x/y coordinates above are treated
# as planar coordinates in meters. This keeps the tests deterministic and makes
# the speed thresholds easy to reason about.
make_test_move2 <- function(x, y, time, track_id) {
  stopifnot(length(x) == length(y))
  stopifnot(length(x) == length(time))
  stopifnot(length(x) == length(track_id))
  
  events <- data.frame(
    x = x,
    y = y,
    date_time = as.POSIXct(time, tz = "UTC"),
    bird_id = as.factor(track_id)
  )
  
  ids <- unique(events$bird_id)
  
  meta <- data.frame(
    bird_id = ids,
    species = paste0("species_", seq_along(ids))
  )
  
  meta$colony_sf <- sf::st_sfc(
    lapply(seq_along(ids), function(i) sf::st_point(c(0, 0))),
    crs = 27700
  )
  meta <- sf::st_as_sf(meta, sf_column_name = "colony_sf")
  
  tt_read_data(
    events = events,
    col_track_id = "bird_id",
    col_coords = c("x", "y"),
    col_date_time = "date_time",
    crs = 27700,
    meta = meta
  )
}

test_that("event_flag_mcconnell rejects non-move2 input", {
  expect_error(
    event_flag_mcconnell(data.frame(x = 1:3), units::as_units(10, "m/h")),
    "x must be a move2 object"
  )
})


test_that("event_flag_mcconnell requires max_speed", {
  x <- make_test_move2(
    x = c(0, 1, 2, 3),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )
  
  expect_error(
    event_flag_mcconnell(x),
    "max_speed must be provided"
  )
})


test_that("event_flag_mcconnell requires max_speed as units", {
  x <- make_test_move2(
    x = c(0, 1, 2, 3),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )
  
  expect_error(
    event_flag_mcconnell(x, max_speed = 10),
    "max_speed must be a units object"
  )
})


test_that("event_flag_mcconnell returns a logical vector of event length", {
  x <- make_test_move2(
    x = c(0, 1, 2, 3),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )
  
  out <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    first_last = FALSE
  )
  
  expect_type(out, "logical")
  expect_length(out, 4)
  expect_identical(out, c(TRUE, TRUE, TRUE, TRUE))
})


test_that("first point is deterministically flagged when first_last = TRUE", {
  # Deterministic projected example (meters, hourly timestamps).
  # Without endpoint handling, all points survive.
  # With endpoint handling, only the first point is removed.
  x <- make_test_move2(
    x = c(0, 20, 10, 0),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )
  
  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    first_last = FALSE
  )
  
  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    first_last = TRUE
  )
  
  expect_identical(out_no_endpoints, c(TRUE, TRUE, TRUE, TRUE))
  expect_identical(out_with_endpoints, c(FALSE, TRUE, TRUE, TRUE))
})


test_that("last point is deterministically flagged when first_last = TRUE", {
  # Deterministic projected example (meters, hourly timestamps).
  # Without endpoint handling, all points survive.
  # With endpoint handling, only the last point is removed.
  x <- make_test_move2(
    x = c(0, 0, 0, 40),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )
  
  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(30, "m/h"),
    first_last = FALSE
  )
  
  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(30, "m/h"),
    first_last = TRUE
  )
  
  expect_identical(out_no_endpoints, c(TRUE, TRUE, TRUE, TRUE))
  expect_identical(out_with_endpoints, c(TRUE, TRUE, TRUE, FALSE))
})


test_that("first_last = TRUE reruns the algorithm deterministically", {
  # Deterministic rerun example for the endpoint-first implementation.
  #
  # Full track:
  #   c(200, 40, 170, 60, 20)
  #
  # Expected behaviour:
  # - first_last = FALSE (McConnell core only): point 3 is removed
  # - first_last = TRUE:
  #     * point 1 is removed by the endpoint RMS check,
  #     * after re-evaluating the new endpoints, point 2 is removed,
  #     * after re-evaluating again, point 3 is removed,
  #   leaving only points 4 and 5 as valid.
  x <- make_test_move2(
    x = c(200, 40, 170, 60, 20),
    y = c(0, 0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800, 14400),
    track_id = rep("a", 5)
  )
  
  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(90, "m/h"),
    first_last = FALSE
  )
  
  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(90, "m/h"),
    first_last = TRUE
  )
  
  expect_identical(
    out_no_endpoints,
    c(TRUE, TRUE, FALSE, TRUE, TRUE)
  )
  
  expect_identical(
    out_with_endpoints,
    c(FALSE, FALSE, FALSE, TRUE, TRUE)
  )
})


test_that("multiple track IDs are handled independently", {
  x <- make_test_move2(
    x = c(0, 20, 10, 0,   0, 5, 10, 15),
    y = c(0, 0, 0, 0,     0, 0, 0, 0),
    time = c(
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
      as.POSIXct("2020-01-02 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800)
    ),
    track_id = c(rep("a", 4), rep("b", 4))
  )
  
  out <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    first_last = TRUE
  )
  
  expect_identical(
    out,
    c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)
  )
})


################################################################################
# Check equivalency to trip::speedfilter
skip_if_not_installed("trip")

walrus_sub <- trip::walrus818[1:600, ]
# create a walrus dataset
walrus_mt <- mt_as_move2(walrus_sub)

test_that("event_flag_mcconnell works correctly", {
  walrus_cleaned <-
    event_flag_mcconnell(walrus_mt,
                         max_speed = as_units(1000, "m/h"))
  # compare the output of event_flag_mcconnell with the output of speedfilter
  # it works for projected distances, but it will not for longlat
  expect_true(all.equal(
    trip::speedfilter(walrus_sub, max.speed = 1000),
    walrus_cleaned
  ))
  # check that units are handle correctly
  expect_true(all.equal(
    event_flag_mcconnell(mt_as_move2(trip::walrus818[1:600, ]),
                         max_speed = as_units(1, "km/h")
    ),
    walrus_cleaned))
})

test_that("tt_clean_mcconnel correctly handles filtered data",{
  # first check that setting to null works
  walrus_clean_null <- tt_clean_mcconnell(walrus_mt,
                                          max_speed = as_units(1000, "m/h"),
                                          flag_action = "null")
  walrus_clean_rm <- tt_clean_mcconnell(walrus_mt,
                                        max_speed = as_units(1000, "m/h"),
                                        flag_action = "remove")
  # removing the null points should give us the same as removing them directly
  expect_true(identical(walrus_clean_null[!sf::st_is_empty(walrus_clean_null),],
                        walrus_clean_rm))
})
