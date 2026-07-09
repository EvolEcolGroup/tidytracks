library(sf)

# tolerances for coordinate and attribute comparison
TOL_COORD <- 1e-6
TOL_ATTR <- 1e-6

# Convenience constructors for units objects
s <- function(x) units::set_units(x, "s")
mn <- function(x) units::set_units(x, "min")

# ── Fixtures ──────────────────────────────────────────────────────────────────
# Three-point track at t = 0, 100, 200 s along (0,0)→(1,0)→(2,0).
make_track <- function(crs = NA) {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 100, 200)
  coords <- list(
    sf::st_point(c(0, 0)),
    sf::st_point(c(1, 0)),
    sf::st_point(c(2, 0))
  )
  geom <- if (is.na(crs)) sf::st_sfc(coords) else sf::st_sfc(coords, crs = crs)
  move2::mt_as_move2(
    sf::st_sf(
      timestamp = times,
      value = c(0, 10, 20),
      track_id = "a",
      geometry = geom
    ),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
}

# Coordinates of x sorted by time (unnamed matrix for clean comparisons).
sorted_coords <- function(x)
  unname(sf::st_coordinates(x[order(move2::mt_time(x)), ]))

# Rows for one track, sorted by time.
track_slice <- function(out, id) {
  sub <- out[as.character(move2::mt_track_id(out)) == id, ]
  sub[order(move2::mt_time(sub)), ]
}

# Make a multi-track: straight line track for one animal.
make_mv <- function(
  id,
  x_off,
  t_offsets = c(0, 100, 200),
  value = c(0, 10, 20)
) {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + t_offsets
  coords <- lapply(
    seq_along(times),
    function(i) sf::st_point(c(i - 1 + x_off, 0))
  )
  move2::mt_as_move2(
    sf::st_sf(
      timestamp = times,
      value = value,
      track_id = id,
      geometry = sf::st_sfc(coords)
    ),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
}


# ─────────────────────────────────────────────────────────────────────────────
# 1. OUTPUT STRUCTURE
# ─────────────────────────────────────────────────────────────────────────────
test_that("output is a move2 object", {
  expect_true(move2::mt_is_move2(tt_regular_time(
    make_track(),
    interval = s(100)
  )))
})

test_that("time and track-id column names are preserved", {
  track <- make_track()
  out <- tt_regular_time(track, interval = s(100))
  expect_equal(move2::mt_time_column(out), move2::mt_time_column(track))
  expect_equal(move2::mt_track_id_column(out), move2::mt_track_id_column(track))
})

test_that("event attribute columns are preserved", {
  expect_true(
    "value" %in% names(tt_regular_time(make_track(), interval = s(100)))
  )
})

test_that("geometry type is POINT throughout output", {
  out <- tt_regular_time(make_track(crs = 4326), interval = s(100))
  expect_true(all(sf::st_geometry_type(out) == "POINT"))
})

test_that("output CRS matches input CRS", {
  track <- make_track(crs = 4326)
  out <- tt_regular_time(track, interval = s(100))
  expect_equal(sf::st_crs(out), sf::st_crs(track))
})

test_that("output has no CRS when input has no CRS", {
  expect_true(is.na(sf::st_crs(tt_regular_time(
    make_track(crs = NA),
    interval = s(100)
  ))))
})

test_that("track-level attributes are preserved", {
  track <- move2::mutate_track_data(make_track(), species = "wolf", age = 3L)
  out <- tt_regular_time(track, interval = s(100))
  td <- move2::mt_track_data(out)
  expect_equal(td$species, "wolf")
  expect_equal(td$age, 3L)
})


# ─────────────────────────────────────────────────────────────────────────────
# 2. UNITS CONVERSION
# ─────────────────────────────────────────────────────────────────────────────
test_that("interval in minutes produces the same grid as equivalent seconds", {
  out_s <- tt_regular_time(make_track(), interval = s(60))
  out_min <- tt_regular_time(make_track(), interval = mn(1))
  expect_equal(
    as.numeric(move2::mt_time(out_s)),
    as.numeric(move2::mt_time(out_min))
  )
})

test_that("max_time_lag in minutes works identically to equivalent seconds", {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 300)
  geom <- sf::st_sfc(list(sf::st_point(c(0, 0)), sf::st_point(c(3, 0))))
  track <- move2::mt_as_move2(
    sf::st_sf(timestamp = times, track_id = "a", geometry = geom),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
  out_s <- tt_regular_time(track, interval = s(100), max_time_lag = s(150))
  out_min <- tt_regular_time(track, interval = s(100), max_time_lag = mn(2.5))
  expect_equal(nrow(out_s), nrow(out_min))
})


# ─────────────────────────────────────────────────────────────────────────────
# 3. TIME GRID REGULARITY
# ─────────────────────────────────────────────────────────────────────────────
test_that("output timestamps are regularly spaced", {
  out <- tt_regular_time(make_track(), interval = s(50))
  gaps <- as.numeric(diff(sort(move2::mt_time(out))), units = "secs")
  expect_true(all(abs(gaps - 50) < 1e-9))
})

test_that("output spans from first to last input timestamp", {
  track <- make_track()
  out <- tt_regular_time(track, interval = s(50))
  expect_equal(
    min(as.numeric(move2::mt_time(out))),
    min(as.numeric(move2::mt_time(track)))
  )
  expect_equal(
    max(as.numeric(move2::mt_time(out))),
    max(as.numeric(move2::mt_time(track)))
  )
})


# ─────────────────────────────────────────────────────────────────────────────
# 4. MIDPOINT CORRECTNESS
# ─────────────────────────────────────────────────────────────────────────────
test_that("[no CRS] midpoint of straight line is correct", {
  co <- sorted_coords(tt_regular_time(make_track(crs = NA), interval = s(100)))
  expect_equal(co[2, 1], 1, tolerance = TOL_COORD)
  expect_equal(co[2, 2], 0, tolerance = TOL_COORD)
})

test_that("[geographic CRS] midpoint of straight line is correct", {
  co <- sorted_coords(tt_regular_time(
    make_track(crs = 4326),
    interval = s(100)
  ))
  expect_equal(co[2, 1], 1, tolerance = 1e-4)
  expect_equal(co[2, 2], 0, tolerance = 1e-4)
})

test_that("[projected CRS] midpoint of straight line is correct", {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 100, 200)
  geom <- sf::st_sfc(
    list(
      sf::st_point(c(500000, 0)),
      sf::st_point(c(501000, 0)),
      sf::st_point(c(502000, 0))
    ),
    crs = 32632
  )
  track <- move2::mt_as_move2(
    sf::st_sf(
      timestamp = times,
      value = c(0, 10, 20),
      track_id = "a",
      geometry = geom
    ),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
  co <- sorted_coords(tt_regular_time(track, interval = s(100)))
  expect_equal(co[2, 1], 501000, tolerance = 1)
  expect_equal(co[2, 2], 0, tolerance = 1)
})


# ─────────────────────────────────────────────────────────────────────────────
# 5. ENDPOINT PRESERVATION
# ─────────────────────────────────────────────────────────────────────────────
test_that("first and last output points match input endpoints", {
  for (crs in list(NA, 4326)) {
    track <- make_track(crs = crs)
    out <- tt_regular_time(track, interval = s(100))
    ci <- unname(sf::st_coordinates(track))
    co <- sorted_coords(out)
    n <- nrow(co)
    expect_equal(co[1, 1], ci[1, 1], tolerance = TOL_COORD)
    expect_equal(co[1, 2], ci[1, 2], tolerance = TOL_COORD)
    expect_equal(co[n, 1], ci[nrow(ci), 1], tolerance = TOL_COORD)
    expect_equal(co[n, 2], ci[nrow(ci), 2], tolerance = TOL_COORD)
  }
})


# ─────────────────────────────────────────────────────────────────────────────
# 6. ATTRIBUTE INTERPOLATION
# ─────────────────────────────────────────────────────────────────────────────
test_that("numeric attribute is correct at 100 s grid", {
  out <- tt_regular_time(make_track(crs = NA), interval = s(100))
  expect_equal(
    out[order(move2::mt_time(out)), ]$value,
    c(0, 10, 20),
    tolerance = TOL_ATTR
  )
})

test_that("numeric attribute is correct at 50 s grid", {
  out <- tt_regular_time(make_track(crs = NA), interval = s(50))
  expect_equal(
    out[order(move2::mt_time(out)), ]$value,
    c(0, 5, 10, 15, 20),
    tolerance = TOL_ATTR
  )
})

test_that("units attributes keep units class after interpolation", {
  track <- make_track(crs = NA)
  track$speed <- units::set_units(c(1, 3, 5), "m/s")

  out <- tt_regular_time(track, interval = s(50))
  out_sorted <- out[order(move2::mt_time(out)), ]

  expect_true(inherits(out_sorted$speed, "units"))
  expect_true(units::ud_are_convertible(
    units::deparse_unit(out_sorted$speed),
    "m/s"
  ))
  expect_equal(
    as.numeric(out_sorted$speed),
    c(1, 2, 3, 4, 5),
    tolerance = TOL_ATTR
  )
})


# ─────────────────────────────────────────────────────────────────────────────
# 7. IRREGULAR INPUT SPACING
#   t = 0, 60, 200 s; uniform spatial spacing.
#   At t = 100: space_frac = 0.5 + (40/140)*0.5 ≈ 0.6429 → X ≈ 1.2857
# ─────────────────────────────────────────────────────────────────────────────
test_that("[no CRS] irregular input spacing maps time correctly to space", {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 60, 200)
  geom <- sf::st_sfc(list(
    sf::st_point(c(0, 0)),
    sf::st_point(c(1, 0)),
    sf::st_point(c(2, 0))
  ))
  track <- move2::mt_as_move2(
    sf::st_sf(timestamp = times, track_id = "a", geometry = geom),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
  co <- sorted_coords(tt_regular_time(track, interval = s(100)))
  expected_x <- (0.5 + (40 / 140) * 0.5) * 2
  expect_equal(co[2, 1], expected_x, tolerance = 1e-3)
})


# ─────────────────────────────────────────────────────────────────────────────
# 8. DIAGONAL PATH
# ─────────────────────────────────────────────────────────────────────────────
test_that("[no CRS] midpoint of diagonal path is correct", {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 100, 200)
  geom <- sf::st_sfc(list(
    sf::st_point(c(0, 0)),
    sf::st_point(c(1, 1)),
    sf::st_point(c(2, 2))
  ))
  track <- move2::mt_as_move2(
    sf::st_sf(timestamp = times, track_id = "a", geometry = geom),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
  co <- sorted_coords(tt_regular_time(track, interval = s(100)))
  expect_equal(co[2, 1], 1, tolerance = TOL_COORD)
  expect_equal(co[2, 2], 1, tolerance = TOL_COORD)
})


# ─────────────────────────────────────────────────────────────────────────────
# 9. MULTI-TRACK SUPPORT
# ─────────────────────────────────────────────────────────────────────────────
test_that("all tracks appear in output", {
  out <- tt_regular_time(
    move2::mt_stack(make_mv("a", 0), make_mv("b", 10)),
    interval = s(100)
  )
  expect_equal(move2::mt_n_tracks(out), 2L)
  expect_setequal(as.character(unique(move2::mt_track_id(out))), c("a", "b"))
})

test_that("each track has regular gaps after resampling", {
  out <- tt_regular_time(
    move2::mt_stack(
      make_mv("a", 0, c(0, 80, 200)),
      make_mv("b", 0, c(0, 130, 200))
    ),
    interval = s(100)
  )
  for (id in c("a", "b")) {
    gaps <- as.numeric(
      diff(move2::mt_time(track_slice(out, id))),
      units = "secs"
    )
    expect_true(
      all(abs(gaps - 100) < 1e-9),
      label = paste("regular gaps for track", id)
    )
  }
})

test_that("each track's midpoint is geometrically correct", {
  out <- tt_regular_time(
    move2::mt_stack(make_mv("a", 0), make_mv("b", 10)),
    interval = s(100)
  )
  mid_a <- unname(sorted_coords(track_slice(out, "a"))[2, 1])
  mid_b <- unname(sorted_coords(track_slice(out, "b"))[2, 1])
  expect_equal(mid_a, 1, tolerance = TOL_COORD)
  expect_equal(mid_b, 11, tolerance = TOL_COORD)
})


# ─────────────────────────────────────────────────────────────────────────────
# 10. max_time_lag RESPECTED
# ─────────────────────────────────────────────────────────────────────────────
test_that("grid points inside gaps > max_time_lag are dropped", {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(0, 300)
  geom <- sf::st_sfc(list(sf::st_point(c(0, 0)), sf::st_point(c(3, 0))))
  track <- move2::mt_as_move2(
    sf::st_sf(timestamp = times, track_id = "a", geometry = geom),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
  # No limit: t = 0, 100, 200, 300 → 4 rows
  expect_equal(nrow(tt_regular_time(track, interval = s(100))), 4L)
  # 300 s gap > 150 s limit → interior points t = 100, 200 dropped → 2 rows
  expect_equal(
    nrow(tt_regular_time(track, interval = s(100), max_time_lag = s(150))),
    2L
  )
})


# ─────────────────────────────────────────────────────────────────────────────
# 11. INPUT VALIDATION — units enforcement
# ─────────────────────────────────────────────────────────────────────────────
test_that("plain numeric interval raises an error mentioning 'units'", {
  expect_error(tt_regular_time(make_track(), interval = 100), "units")
})

test_that("vector interval raises a clear length-1 error", {
  expect_error(
    tt_regular_time(make_track(), interval = s(c(60, 120))),
    "length-1"
  )
})

test_that("non-time units for interval raises an error mentioning 'seconds'", {
  expect_error(
    tt_regular_time(make_track(), interval = units::set_units(1, "m")),
    "seconds"
  )
})

test_that("plain numeric max_time_lag raises an error mentioning 'units'", {
  expect_error(
    tt_regular_time(make_track(), interval = s(100), max_time_lag = 150),
    "units"
  )
})

test_that("non-time units for max_time_lag raises an error mentioning 'seconds'", {
  expect_error(
    tt_regular_time(
      make_track(),
      interval = s(100),
      max_time_lag = units::set_units(1, "m")
    ),
    "seconds"
  )
})

test_that("vector max_time_lag raises a clear length-1 error", {
  expect_error(
    tt_regular_time(
      make_track(),
      interval = s(100),
      max_time_lag = s(c(50, 60))
    ),
    "length-1"
  )
})

test_that("negative interval raises an error", {
  expect_error(tt_regular_time(make_track(), interval = s(-100)))
})

test_that("zero interval raises an error", {
  expect_error(tt_regular_time(make_track(), interval = s(0)))
})

test_that("non-move2 input raises an error mentioning 'move2'", {
  expect_error(tt_regular_time(data.frame(x = 1), interval = s(100)), "move2")
})

test_that("non-POSIXct timestamps raise an error mentioning 'POSIXct'", {
  expect_error(
    tt_regular_time(
      move2::mt_sim_brownian_motion(t = c(0, 100, 200), tracks = "a"),
      interval = s(100)
    ),
    "POSIXct"
  )
})

test_that("single-point track raises an error mentioning 'at least 2'", {
  expect_error(
    tt_regular_time(make_track()[1L, ], interval = s(100)),
    "at least 2"
  )
})

test_that("unsorted input timestamps are handled correctly", {
  track <- make_track(crs = NA)
  unsorted <- track[c(3, 1, 2), ]
  out_sorted <- tt_regular_time(track, interval = s(50))
  out_unsorted <- tt_regular_time(unsorted, interval = s(50))

  expect_equal(
    as.numeric(move2::mt_time(out_unsorted)),
    as.numeric(move2::mt_time(out_sorted))
  )
  expect_equal(
    sorted_coords(out_unsorted),
    sorted_coords(out_sorted),
    tolerance = TOL_COORD
  )
})

test_that("tracks fully removed by gap filtering return valid empty output", {
  mv <- move2::mt_stack(
    make_mv("drop", x_off = 0, t_offsets = c(40, 70), value = c(0, 10)),
    make_mv("keep", x_off = 10, t_offsets = c(0, 100, 250), value = c(0, 5, 10))
  )
  out <- tt_regular_time(
    mv,
    interval = s(100),
    max_time_lag = s(10),
    snap_times = TRUE
  )

  expect_false("drop" %in% as.character(unique(move2::mt_track_id(out))))
  expect_true("keep" %in% as.character(unique(move2::mt_track_id(out))))
  expect_equal(as.character(move2::mt_track_data(out)$track_id), "keep")
})


# ─────────────────────────────────────────────────────────────────────────────
# 12. snap_times BEHAVIOUR
# ─────────────────────────────────────────────────────────────────────────────

# Helper: make a track starting at a fractional offset within the interval.
# track "a" starts at t=+40 s, track "b" starts at t=+70 s.
# With interval = 100 s, both should snap to t=+100 s as their first point.
make_offset_mv <- function(id, t_start, t_end = 300) {
  times <- as.POSIXct("2024-01-01", tz = "UTC") + c(t_start, t_end)
  coords <- list(sf::st_point(c(0, 0)), sf::st_point(c(3, 0)))
  move2::mt_as_move2(
    sf::st_sf(
      timestamp = times,
      track_id = id,
      geometry = sf::st_sfc(coords)
    ),
    time_column = "timestamp",
    track_id_column = "track_id"
  )
}

test_that("snap_times=TRUE: first grid point is the next whole-interval boundary", {
  set.seed(123)
  # Track starts at t = 40 s; interval = 100 s → first snapped point at t = 100 s
  track <- make_offset_mv("a", t_start = 40, t_end = 300)
  out <- tt_regular_time(track, interval = s(100), snap_times = TRUE)
  t_out <- sort(as.numeric(move2::mt_time(out)))
  epoch <- as.numeric(as.POSIXct("2024-01-01", tz = "UTC"))
  # First point must be exactly 100 s after epoch (the next whole-100s boundary)
  expect_equal(t_out[1L] - epoch, 100, tolerance = 1e-9)
})

test_that("snap_times=TRUE: grid remains regularly spaced after snapping", {
  track <- make_offset_mv("a", t_start = 40, t_end = 350)
  out <- tt_regular_time(track, interval = s(100), snap_times = TRUE)
  gaps <- diff(sort(as.numeric(move2::mt_time(out))))
  expect_true(all(abs(gaps - 100) < 1e-9))
})

test_that("snap_times=FALSE: first grid point equals track start (default behaviour)", {
  track <- make_offset_mv("a", t_start = 40, t_end = 300)
  out <- tt_regular_time(track, interval = s(100), snap_times = FALSE)
  t_out <- sort(as.numeric(move2::mt_time(out)))
  epoch <- as.numeric(as.POSIXct("2024-01-01", tz = "UTC"))
  expect_equal(t_out[1L] - epoch, 40, tolerance = 1e-9)
})

test_that("snap_times=TRUE: overlapping tracks share timestamps", {
  # Track "a" starts at t=+40 s, track "b" starts at t=+70 s.
  # Both cover through t=+300 s. Interval = 100 s.
  # Snapped grids: a → {100, 200, 300}, b → {100, 200, 300}  (identical)
  mv <- move2::mt_stack(
    make_offset_mv("a", t_start = 40, t_end = 300),
    make_offset_mv("b", t_start = 70, t_end = 300)
  )
  out <- tt_regular_time(mv, interval = s(100), snap_times = TRUE)
  times_a <- sort(as.numeric(move2::mt_time(track_slice(out, "a"))))
  times_b <- sort(as.numeric(move2::mt_time(track_slice(out, "b"))))
  # The two grids must be identical
  expect_equal(times_a, times_b)
  # And there must be shared timestamps across the combined output
  all_times <- as.numeric(move2::mt_time(out))
  expect_true(
    any(duplicated(all_times)),
    label = "at least one timestamp shared across tracks when snap_times=TRUE"
  )
})

test_that("snap_times=FALSE: overlapping tracks do NOT share timestamps", {
  # Same offsets as above but without snapping — grids start at 40 and 70,
  # producing {40, 140, 240} and {70, 170, 270}: no common values.
  mv <- move2::mt_stack(
    make_offset_mv("a", t_start = 40, t_end = 300),
    make_offset_mv("b", t_start = 70, t_end = 300)
  )
  out <- tt_regular_time(mv, interval = s(100), snap_times = FALSE)
  all_times <- as.numeric(move2::mt_time(out))
  expect_false(
    any(duplicated(all_times)),
    label = "no shared timestamps across tracks when snap_times=FALSE"
  )
})

test_that("snap_times=TRUE: aligned track starts at the next boundary", {
  # Start exactly on a 100 s boundary (t = 200 s after epoch).
  # The next boundary is t = 300 s, so the grid would lose the first point.
  # This verifies correct ceiling arithmetic: 200 / 100 = 2 (whole), so
  # snapped start = 200 + 100 = 300.
  track <- make_offset_mv("a", t_start = 200, t_end = 500)
  out_snap <- tt_regular_time(track, interval = s(100), snap_times = TRUE)
  out_raw <- tt_regular_time(track, interval = s(100), snap_times = FALSE)
  epoch <- as.numeric(as.POSIXct("2024-01-01", tz = "UTC"))
  # Raw starts at 200; snapped must start at 300
  expect_equal(
    min(as.numeric(move2::mt_time(out_raw))) - epoch,
    200,
    tolerance = 1e-9
  )
  expect_equal(
    min(as.numeric(move2::mt_time(out_snap))) - epoch,
    300,
    tolerance = 1e-9
  )
})

test_that("invalid snap_times value raises an error", {
  expect_error(
    tt_regular_time(make_track(), interval = s(100), snap_times = "yes"),
    "snap_times"
  )
})
