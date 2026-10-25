skip_if_not_installed("ctmm")

test_that("mt_as_telemetry returns one telemetry object per track", {
  x <- ctmm_example_tt()
  tel <- suppressMessages(mt_as_telemetry(x))
  expect_type(tel, "list")
  expect_named(tel, c("Cilla", "Gabs"))
  expect_true(all(vapply(tel, inherits, logical(1), "telemetry")))
  expect_equal(unname(vapply(tel, nrow, integer(1))), c(100L, 100L))
  # only the time, location and derived columns are passed to ctmm
  expect_setequal(
    names(tel$Cilla),
    c("timestamp", "longitude", "latitude", "t", "x", "y")
  )
  # a single track still gives a list
  tel_one <- suppressMessages(
    mt_as_telemetry(filter_by_meta(x, track == "Gabs"))
  )
  expect_type(tel_one, "list")
  expect_named(tel_one, "Gabs")
})

test_that("mt_as_telemetry keeps the coordinates of x", {
  x <- ctmm_example_tt()
  tel <- suppressMessages(mt_as_telemetry(x))
  for (track_id in names(tel)) {
    x_track <- filter_by_meta(x, track == track_id)
    xy <- sf::st_coordinates(x_track)[order(event_time(x_track)), ]
    expect_identical(tel[[track_id]]$x, unname(xy[, 1]))
    expect_identical(tel[[track_id]]$y, unname(xy[, 2]))
  }
  # the PROJ4 representation of the British National Grid used by ctmm lacks
  # the datum transformation, which would shift the locations if ctmm
  # projected them itself
  uk <- data.frame(
    id = "a",
    time = as.POSIXct("2024-01-01", tz = "UTC") + (0:9) * 3600,
    lon = -1 + (0:9) / 100,
    lat = 52 + sin(0:9) / 100
  )
  uk <- move2::mt_as_move2(
    uk,
    coords = c("lon", "lat"),
    time_column = "time",
    track_id_column = "id",
    crs = 4326
  ) %>%
    sf::st_transform(27700)
  tel_uk <- suppressMessages(mt_as_telemetry(uk))
  expect_identical(tel_uk$a$x, unname(sf::st_coordinates(uk)[, 1]))
  expect_identical(tel_uk$a$y, unname(sf::st_coordinates(uk)[, 2]))
})

test_that("mt_as_telemetry returns the tracks in the order of the metadata", {
  x <- ctmm_example_tt()
  # reverse the order of the tracks in the metadata, and of the events
  show_meta(x) <- show_meta(x)[2:1, , drop = FALSE]
  x <- x[rev(seq_len(nrow(x))), ]
  tel <- suppressMessages(mt_as_telemetry(x))
  expect_named(tel, c("Gabs", "Cilla"))
  # the events are sorted by time within each track
  expect_false(is.unsorted(tel$Gabs$t))
})

test_that("mt_as_telemetry round-trips with mt_as_move2", {
  x <- ctmm_example_tt()
  tel <- suppressMessages(mt_as_telemetry(x))
  x_back <- mt_as_move2(tel)
  expect_equal(
    sf::st_coordinates(x_back),
    sf::st_coordinates(x),
    ignore_attr = TRUE
  )
  expect_equal(
    as.character(event_track_id(x_back)),
    as.character(event_track_id(x))
  )
})

test_that("mt_as_telemetry drops events and tracks without a location", {
  x <- ctmm_example_tt(n = 10)
  # remove the location of three events of Cilla, and of all events of Gabs
  empty <- c(2:4, which(event_track_id(x) == "Gabs"))
  sf::st_geometry(x)[empty] <- sf::st_point()
  tel <- suppressMessages(mt_as_telemetry(x))
  expect_named(tel, "Cilla")
  expect_equal(nrow(tel$Cilla), 7)
  # no location at all
  sf::st_geometry(x)[seq_len(nrow(x))] <- sf::st_point()
  expect_error(mt_as_telemetry(x), "no events with a location")
})

test_that("mt_as_telemetry passes the error columns", {
  x <- ctmm_example_tt(n = 10)
  x$gps_hdop <- seq_len(nrow(x))
  # a column that ctmm would recognise as an id is not passed
  x$tag_local_identifier <- "tag"
  tel <- suppressMessages(mt_as_telemetry(x))
  expect_true("HDOP" %in% names(tel$Cilla))
  expect_equal(tel$Cilla$HDOP, 1:10)
  expect_named(tel, c("Cilla", "Gabs"))
  # no error columns
  tel <- suppressMessages(mt_as_telemetry(x, error_cols = NULL))
  expect_false("HDOP" %in% names(tel$Cilla))
  # columns given explicitly (with units, which are dropped)
  tel <- suppressMessages(mt_as_telemetry(x, error_cols = "gps_hdop"))
  expect_equal(tel$Cilla$HDOP, 1:10)
  # columns renamed to the names used by ctmm
  x$my_hdop <- units::set_units(seq_len(nrow(x)) * 2, "1")
  x$gps_hdop <- NULL
  tel <- suppressMessages(
    mt_as_telemetry(x, error_cols = c(HDOP = "my_hdop"))
  )
  expect_equal(tel$Cilla$HDOP, (1:10) * 2)
  # ctmm ignores columns with names that it does not recognise
  tel <- suppressMessages(mt_as_telemetry(x, error_cols = "my_hdop"))
  expect_false("HDOP" %in% names(tel$Cilla))
  expect_error(
    mt_as_telemetry(x, error_cols = "missing_col"),
    "error_cols not found"
  )
})

test_that("mt_as_telemetry requires a projected CRS in metres", {
  x <- ctmm_example_tt(n = 10)
  expect_error(
    mt_as_telemetry(sf::st_transform(x, 4326)),
    "crstools::suggest_crs"
  )
  # US survey feet
  x_feet <- sf::st_transform(
    x,
    "+proj=aeqd +lat_0=-25 +lon_0=31.8 +units=us-ft"
  )
  expect_error(mt_as_telemetry(x_feet), "units in metres")
  expect_error(mt_as_telemetry(sf::st_set_crs(x, NA)), "no coordinate")
  expect_error(mt_as_telemetry(as.data.frame(x)), "must be a move2 object")
})
