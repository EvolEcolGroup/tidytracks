# -----------------------------------------------------------------------------
# Test helper
# -----------------------------------------------------------------------------
# Minimal move2 constructor for tests, following the structure of the toy
# example used in the discussion.
#
# We use a projected CRS (EPSG:27700), so the x/y coordinates above are treated
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


test_that("event_flag_mcconnell requires a CRS", {
  expect_error(
    event_flag_mcconnell(
      sf::st_set_crs(example_tt, NA),
      max_speed = units::as_units(10, "m/s")
    ),
    "x must have a coordinate reference system"
  )
})


test_that("event_flag_mcconnell requires max_speed", {
  x <- make_test_move2(
    x = c(0, 1, 2, 3),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800),
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
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800),
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
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )

  out <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    check_first_last = FALSE
  )

  expect_type(out, "logical")
  expect_length(out, 4)
  expect_identical(out, c(TRUE, TRUE, TRUE, TRUE))
})


test_that("endpoint checks flag the first point deterministically", {
  # Deterministic projected example (meters, hourly timestamps).
  # Without endpoint handling, all points survive.
  # With endpoint handling, only the first point is removed.
  x <- make_test_move2(
    x = c(0, 20, 10, 0),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )

  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    check_first_last = FALSE
  )

  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    check_first_last = TRUE
  )

  expect_identical(out_no_endpoints, c(TRUE, TRUE, TRUE, TRUE))
  expect_identical(out_with_endpoints, c(FALSE, TRUE, TRUE, TRUE))
})


test_that("endpoint checks flag the last point deterministically", {
  # Deterministic projected example (meters, hourly timestamps).
  # Without endpoint handling, all points survive.
  # With endpoint handling, only the last point is removed.
  x <- make_test_move2(
    x = c(0, 0, 0, 40),
    y = c(0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800),
    track_id = rep("a", 4)
  )

  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(30, "m/h"),
    check_first_last = FALSE
  )

  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(30, "m/h"),
    check_first_last = TRUE
  )

  expect_identical(out_no_endpoints, c(TRUE, TRUE, TRUE, TRUE))
  expect_identical(out_with_endpoints, c(TRUE, TRUE, TRUE, FALSE))
})


test_that("check_first_last = TRUE reruns the algorithm deterministically", {
  # Deterministic rerun example for the endpoint-first implementation.
  #
  # The full track has x coordinates 200, 40, 170, 60, and 20.
  #
  # Expected behaviour:
  # - check_first_last = FALSE (McConnell core only): point 3 is removed
  # - check_first_last = TRUE:
  #     * point 1 is removed by the endpoint RMS check,
  #     * after re-evaluating the new endpoints, point 2 is removed,
  #     * after re-evaluating again, point 3 is removed,
  #   leaving only points 4 and 5 as valid.
  x <- make_test_move2(
    x = c(200, 40, 170, 60, 20),
    y = c(0, 0, 0, 0, 0),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 3600, 7200, 10800, 14400),
    track_id = rep("a", 5)
  )

  out_no_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(90, "m/h"),
    check_first_last = FALSE
  )

  out_with_endpoints <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(90, "m/h"),
    check_first_last = TRUE
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


test_that("endpoint checks flag endpoints with an infinite speed", {
  # the first location is 1 km away from the second one, at the same time
  x <- make_test_move2(
    x = c(1000, 0, 100, 200, 300, 400),
    y = rep(0, 6),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 0, 600, 1200, 1800, 2400),
    track_id = rep("a", 6)
  )

  out <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "km/h"),
    check_first_last = TRUE
  )

  expect_identical(out, c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE))
})


test_that("multiple track IDs are handled independently", {
  x <- make_test_move2(
    x = c(0, 20, 10, 0, 0, 5, 10, 15),
    y = c(0, 0, 0, 0, 0, 0, 0, 0),
    time = c(
      as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800),
      as.POSIXct("2020-01-02 00:00:00", tz = "UTC") + c(0, 3600, 7200, 10800)
    ),
    track_id = c(rep("a", 4), rep("b", 4))
  )

  out <- event_flag_mcconnell(
    x,
    max_speed = units::as_units(10, "m/h"),
    check_first_last = TRUE
  )

  expect_identical(
    out,
    c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE)
  )
})


################################################################################
# Guard against infinite loops: fail instead of hanging the test suite
with_time_limit <- function(expr, seconds = 30) {
  setTimeLimit(elapsed = seconds, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf, transient = FALSE))
  expr
}

test_that("duplicated records do not stop a later spike being removed", {
  # the third record is duplicated (same time and place), and the seventh
  # location is a spike 50 km away
  x <- make_test_move2(
    x = c(0, 100, 200, 200, 300, 400, 50000, 600, 700, 800, 900, 1000),
    y = rep(0, 12),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      c(0, 1, 2, 2, 3, 4, 5, 6, 7, 8, 9, 10) * 600,
    track_id = rep("a", 12)
  )

  out <- with_time_limit(
    event_flag_mcconnell(x, max_speed = units::as_units(10, "km/h"))
  )
  expect_identical(out, seq_len(12) != 7)
})

test_that("empty locations are ignored by the filter", {
  x <- make_test_move2(
    x = c(0, 100, 200, 300, 400, 50000, 600, 700, 800, 900),
    y = rep(0, 10),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (0:9) * 600,
    track_id = rep("a", 10)
  )
  sf::st_geometry(x)[3] <- sf::st_point()

  out <- with_time_limit(
    event_flag_mcconnell(x, max_speed = units::as_units(10, "km/h"))
  )
  # the spike is removed, the empty location is kept
  expect_identical(out, seq_len(10) != 6)

  cleaned <- with_time_limit(
    tt_clean_mcconnell(
      x,
      max_speed = units::as_units(10, "km/h"),
      flag_action = "remove"
    )
  )
  expect_equal(nrow(cleaned), 9)
  expect_true(sf::st_is_empty(sf::st_geometry(cleaned)[3]))
})

test_that("outliers late in a long track are removed in later passes", {
  # each pass removes one location of each run of outliers, and the next pass
  # only computes the windows that included a removed location. The two
  # locations of an excursion of 50 km near the end of a long track are
  # removed in two passes
  n <- 50000
  excursion <- c(49000, 49001)
  x_coord <- (seq_len(n) - 1) * 100
  x_coord[excursion] <- x_coord[excursion] + 50000
  x <- make_test_move2(
    x = x_coord,
    y = rep(0, n),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      (seq_len(n) - 1) * 600,
    track_id = rep("a", n)
  )

  out <- with_time_limit(
    event_flag_mcconnell(x, max_speed = units::as_units(10, "km/h"))
  )
  expect_identical(out, !seq_len(n) %in% excursion)
})

test_that("the distance bound is above geodesic distances, also at the poles", {
  # geodesic distances are only computed for the windows that could exceed
  # the maximum speed with an upper bound of the distances, which must never
  # be below the geodesic distance, including over short steps near the
  # poles (where the bound is closest to it)
  lat <- c(-90, -89.9999999, -89.99, -85, -60, 0, 45, 89.99, 90)
  step <- c(0, 0.001, 1, 100, 1e4, 3e5)
  pairs <- expand.grid(lat = lat, step = step, bearing = c(0, 45, 90, 180))
  # the destinations, on a sphere (only to have pairs of nearby locations)
  r <- pairs$step / 6371000
  lat1 <- pairs$lat * pi / 180
  bearing <- pairs$bearing * pi / 180
  lat2 <- asin(pmin(1, pmax(
    -1,
    sin(lat1) * cos(r) + cos(lat1) * sin(r) * cos(bearing)
  )))
  lon2 <- 170 + atan2(
    sin(bearing) * sin(r) * cos(lat1),
    cos(r) - sin(lat1) * sin(lat2)
  ) * 180 / pi
  xy <- cbind(c(rep(170, nrow(pairs)), lon2), c(pairs$lat, lat2 * 180 / pi))
  from <- seq_len(nrow(pairs))
  to <- nrow(pairs) + from
  geodesic <- dist_fast(xy[from, 1], xy[from, 2], xy[to, 1], xy[to, 2])
  bound <- mcconnell_dist_bound(xy, from, to)
  expect_true(all(bound >= geodesic))
  # and it is close enough to save most geodesic distances
  expect_true(all(bound <= geodesic * 1.011 + 1e-5))
})

test_that("a track over the South Pole is filtered", {
  # a track along the meridian 0 to the pole, and on along the meridian 180,
  # at 2 km/h, with a spike 50 km away
  n <- 40
  dist_to_pole <- (seq_len(n) - 20.5) * 2000
  lat <- -90 + abs(dist_to_pole) / 111000
  lon <- ifelse(dist_to_pole < 0, 0, 180)
  lat[30] <- lat[30] + 0.45
  events <- data.frame(
    lon = lon,
    lat = lat,
    date_time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") +
      (seq_len(n) - 1) * 3600,
    bird_id = "a"
  )
  x <- move2::mt_as_move2(
    events,
    coords = c("lon", "lat"),
    crs = 4326,
    time_column = "date_time",
    track_id_column = "bird_id"
  )
  out <- with_time_limit(
    event_flag_mcconnell(x, max_speed = units::as_units(10, "km/h"))
  )
  expect_identical(out, seq_len(n) != 30)
})

test_that("events not stored in time order are filtered in time order", {
  x <- make_test_move2(
    x = c(0, 100, 200, 300, 400, 50000, 600, 700, 800, 900),
    y = rep(0, 10),
    time = as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + (0:9) * 600,
    track_id = rep("a", 10)
  )
  # the spike (sixth location in time) is stored first
  shuffled <- c(6, 1:5, 7:10)
  out <- with_time_limit(
    event_flag_mcconnell(
      x[shuffled, ],
      max_speed = units::as_units(10, "km/h")
    )
  )
  expect_identical(out, shuffled != 6)
})

test_that("timestamps that are dates or units are converted to seconds", {
  # one location a day, with a spike of 500 km on the fifth day
  events <- data.frame(
    x = c(0, 1, 2, 3, 500, 5, 6, 7, 8, 9) * 1000,
    y = 0,
    track = "a"
  )
  for (time in list(
    as.Date("2020-01-01") + 0:9,
    units::set_units((0:9) * 24, "h")
  )) {
    events$time <- time
    x <- move2::mt_as_move2(
      sf::st_as_sf(events, coords = c("x", "y"), crs = 27700),
      time_column = "time",
      track_id_column = "track"
    )
    expect_identical(
      event_flag_mcconnell(x, max_speed = units::as_units(100, "km/d")),
      seq_len(10) != 5
    )
  }
})

# Check equivalency to trip::speedfilter
skip_if_not_installed("trip")

walrus_sub <- trip::walrus818[1:600, ]
# create a walrus dataset
walrus_mt <- mt_as_move2(walrus_sub)

test_that("event_flag_mcconnell works correctly", {
  walrus_cleaned <-
    event_flag_mcconnell(walrus_mt, max_speed = as_units(1000, "m/h"))
  # compare the output of event_flag_mcconnell with the output of speedfilter
  # it works for projected distances, but it will not for longlat
  expect_true(all.equal(
    trip::speedfilter(walrus_sub, max.speed = 1000),
    walrus_cleaned
  ))
  # check that units are handle correctly
  expect_true(all.equal(
    event_flag_mcconnell(
      mt_as_move2(trip::walrus818[1:600, ]),
      max_speed = as_units(1, "km/h")
    ),
    walrus_cleaned
  ))
})

test_that("tt_clean_mcconnel correctly handles filtered data", {
  # first check that setting to null works
  walrus_clean_null <- tt_clean_mcconnell(
    walrus_mt,
    max_speed = as_units(1000, "m/h"),
    flag_action = "null"
  )
  walrus_clean_rm <- tt_clean_mcconnell(
    walrus_mt,
    max_speed = as_units(1000, "m/h"),
    flag_action = "remove"
  )
  # removing the null points should give us the same as removing them directly
  expect_true(identical(
    walrus_clean_null[!sf::st_is_empty(walrus_clean_null), ],
    walrus_clean_rm
  ))
})
