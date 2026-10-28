outlier_methods <- list(
  clean_track = "mt_clean_track",
  speed_cap = "mt_flag_speed_cap",
  detour = "mt_flag_outliers_detour",
  bridge = "mt_flag_outliers_bridge",
  probability = "mt_flag_outliers"
)

# the spikes added by create_spiky_tracks() are 20 km east of the tracks
spike_index <- function(x) {
  which(sf::st_coordinates(x)[, 1] > 10000)
}

test_that("event_flag_outliers gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    event_flag_outliers(data.frame(a = 1:10)),
    "x must be a move2 object"
  )
  x <- create_spiky_tracks()
  x_no_crs <- x
  sf::st_crs(x_no_crs) <- NA
  expect_error(
    event_flag_outliers(x_no_crs),
    "x must have a coordinate reference system"
  )
  expect_error(event_flag_outliers(x, method = "other"))
  expect_error(
    event_flag_outliers(x[c(2, 1, 3:nrow(x)), ]),
    "x must be ordered by time within each track; use tt_order_time"
  )
})

test_that("event_flag_outliers matches move2utils for each method", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  for (method in names(outlier_methods)) {
    valid <- event_flag_outliers(x, method = method)
    direct <- getExportedValue("move2utils", outlier_methods[[method]])(
      x,
      plot = FALSE,
      silent = TRUE,
      remove = FALSE
    )
    expect_type(valid, "logical")
    expect_identical(valid, !direct$is_outlier, info = method)
    # all methods detect the spikes
    expect_false(any(valid[spike_index(x)]), info = method)
  }
})

test_that("event_flag_outliers passes further arguments, converting units", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  valid <- event_flag_outliers(
    x,
    method = "speed_cap",
    v_max = as_units(36, "km/h"),
    threshold_type = "hard"
  )
  direct <- move2utils::mt_flag_speed_cap(
    x,
    v_max = 10,
    threshold_type = "hard",
    plot = FALSE,
    silent = TRUE
  )
  expect_identical(valid, !direct$is_outlier)
  # physical quantities must be given with units
  expect_error(
    event_flag_outliers(
      x,
      method = "speed_cap",
      v_max = 10,
      threshold_type = "hard"
    ),
    "v_max must be a units object"
  )
  expect_error(
    event_flag_outliers(
      x,
      method = "speed_cap",
      v_max = as_units(10, "m"),
      threshold_type = "hard"
    ),
    "v_max must be a units object with units convertible to m/s"
  )
  # an argument in ... that is not an argument of the move2utils function is
  # rejected by it (rather than being partially matched to an internal one)
  expect_error(
    event_flag_outliers(x, method = "detour", f = 1),
    "unused argument"
  )
  # a lower cap (steps are ~0.1 m/s, apart from the spikes) flags more events
  expect_gt(
    sum(!event_flag_outliers(
      x,
      method = "speed_cap",
      v_max = as_units(0.1, "m/s"),
      threshold_type = "hard"
    )),
    sum(!valid)
  )
})

test_that("event_flag_outliers passes values per track with their names", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  # mt_clean_track() matches a mass per track to the tracks by name
  direct <- move2utils::mt_clean_track(
    x,
    mass = c(a = 0.5, b = 800),
    mode = "flying",
    plot = FALSE,
    silent = TRUE,
    remove = FALSE
  )
  expect_identical(
    event_flag_outliers(
      x,
      mass = as_units(c(a = 500, b = 800000), "g"),
      mode = "flying"
    ),
    !direct$is_outlier
  )
})

test_that("event_flag_outliers requires location errors with units", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  x$error_metres <- rep(20, nrow(x))
  direct <- move2utils::mt_flag_outliers_bridge(
    x,
    location_error = "error_metres",
    plot = FALSE,
    silent = TRUE
  )
  # a column of plain numbers is not assumed to be in metres
  expect_error(
    event_flag_outliers(x, method = "bridge", location_error = "error_metres"),
    "the column 'error_metres' used for location_error must be a units object"
  )
  expect_error(
    event_flag_outliers(x, method = "bridge", location_error = "not_a_column"),
    "location_error \\('not_a_column'\\) is not a column of x"
  )
  # a column with units, in any units of length
  x$error_units <- as_units(rep(0.02, nrow(x)), "km")
  expect_identical(
    event_flag_outliers(x, method = "bridge", location_error = "error_units"),
    !direct$is_outlier
  )
  # one value per event
  expect_identical(
    event_flag_outliers(
      x,
      method = "bridge",
      location_error = as_units(rep(20, nrow(x)), "m")
    ),
    !direct$is_outlier
  )
  expect_error(
    event_flag_outliers(
      x,
      method = "bridge",
      location_error = rep(20, nrow(x))
    ),
    "location_error must be a units object"
  )
  expect_error(
    event_flag_outliers(
      x,
      method = "bridge",
      location_error = as_units(c(10, 20), "m")
    ),
    "location_error must have one value, or one value per event"
  )
  # with "auto", move2utils uses the accuracy of e-obs tags, which must have
  # units too
  x$eobs_horizontal_accuracy_estimate <- rep(20, nrow(x))
  expect_error(
    event_flag_outliers(x, method = "bridge", location_error = "auto"),
    "the column 'eobs_horizontal_accuracy_estimate' used for location_error"
  )
  x$eobs_horizontal_accuracy_estimate <- x$error_units
  expect_message(
    valid <- event_flag_outliers(
      x,
      method = "bridge",
      location_error = "auto"
    ),
    "using `eobs_horizontal_accuracy_estimate`"
  )
  expect_identical(valid, !direct$is_outlier)
})

test_that("event_flag_outliers returns events without a location as valid", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  x_empty <- x
  sf::st_geometry(x_empty)[c(10, 20)] <- sf::st_point()
  valid <- event_flag_outliers(x_empty, method = "detour")
  expect_true(all(valid[c(10, 20)]))
  expect_identical(
    valid[-c(10, 20)],
    event_flag_outliers(x[-c(10, 20), ], method = "detour")
  )
  # location errors given per event are matched to the located events
  errors <- as_units(seq(10, 30, length.out = nrow(x)), "m")
  valid <- event_flag_outliers(
    x_empty,
    method = "bridge",
    location_error = errors
  )
  expect_true(all(valid[c(10, 20)]))
  expect_identical(
    valid[-c(10, 20)],
    event_flag_outliers(
      x[-c(10, 20), ],
      method = "bridge",
      location_error = errors[-c(10, 20)]
    )
  )
})

test_that("event_flag_outliers matches a state per event to the events", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  state <- rep(rep(c("rest", "move"), each = 150), 2)
  x_empty <- x
  sf::st_geometry(x_empty)[10] <- sf::st_point()
  # the event without a location is not passed to move2utils, nor is its
  # state
  valid <- event_flag_outliers(x_empty, state = state)
  expect_true(valid[10])
  expect_identical(
    valid[-10],
    event_flag_outliers(x[-10, ], state = state[-10])
  )
})

test_that("event_flag_outliers returns the events of short tracks as valid", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  # the last event of track b becomes a track with a single location, which
  # move2utils cannot combine with the results of the other tracks
  ids <- as.character(event_track_id(x))
  ids[nrow(x)] <- "c"
  x_single <- move2::mt_set_track_id(x, ids)
  for (method in names(outlier_methods)) {
    expect_warning(
      valid <- event_flag_outliers(x_single, method = method),
      "1 track\\(s\\) with fewer than .* were not checked for outliers",
      info = method
    )
    expect_true(valid[nrow(x)], info = method)
    expect_identical(
      valid[-nrow(x)],
      event_flag_outliers(x_single[-nrow(x), ], method = method),
      info = method
    )
  }
  # mt_clean_track() returns tracks with fewer than 10 locations without
  # flags, but cannot combine them with longer tracks
  ids[(nrow(x) - 4):nrow(x)] <- "c"
  x_short <- move2::mt_set_track_id(x, ids)
  expect_warning(
    valid <- event_flag_outliers(x_short),
    "1 track\\(s\\) with fewer than 10 events with a location"
  )
  expect_true(all(valid[ids == "c"]))
  expect_identical(
    valid[ids != "c"],
    event_flag_outliers(x_short[ids != "c", ])
  )
})

test_that("tt_clean_outliers acts on the outliers", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  valid <- event_flag_outliers(x, method = "bridge")
  expect_true(any(!valid))

  removed <- tt_clean_outliers(x, method = "bridge")
  expect_s3_class(removed, "move2")
  expect_identical(nrow(removed), sum(valid))
  expect_identical(event_time(removed), event_time(x)[valid])

  nulled <- tt_clean_outliers(x, method = "bridge", flag_action = "null")
  expect_identical(nrow(nulled), nrow(x))
  expect_identical(sf::st_is_empty(nulled), !valid)

  interpolated <- tt_clean_outliers(
    x,
    method = "bridge",
    flag_action = "interpolate"
  )
  expect_identical(nrow(interpolated), nrow(x))
  expect_false(any(sf::st_is_empty(interpolated)))
  expect_false(any(sf::st_coordinates(interpolated)[, 1] > 10000))

  expect_error(tt_clean_outliers(x, flag_action = "other"))
})

test_that("tt_clean_outliers passes further arguments", {
  skip_if_not_installed("move2utils")
  x <- create_spiky_tracks()
  valid <- event_flag_outliers(
    x,
    method = "speed_cap",
    v_max = as_units(0.1, "m/s"),
    threshold_type = "hard"
  )
  removed <- tt_clean_outliers(
    x,
    method = "speed_cap",
    v_max = as_units(0.1, "m/s"),
    threshold_type = "hard"
  )
  expect_identical(nrow(removed), sum(valid))
})

test_that("event_flag_outliers requires coordinates in metres or degrees", {
  skip_if_not_installed("move2utils")
  # a projected CRS in US survey feet
  x <- sf::st_transform(create_spiky_tracks(), 2263)
  expect_error(
    event_flag_outliers(x, method = "detour"),
    "x must have a geographic coordinate reference system, or a projected"
  )
})
