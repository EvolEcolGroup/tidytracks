# a straight track along x, in metres, with a location every 1000 m and 100 s
create_line_tracks <- function(n = 11, crs = 32631) {
  df <- data.frame(
    id = "a",
    x = 500000 + 1000 * seq(0, n - 1),
    y = 5000000,
    time = as.POSIXct("2024-01-01", tz = "UTC") + 100 * seq(0, n - 1)
  )
  move2::mt_as_move2(
    df,
    coords = c("x", "y"),
    crs = crs,
    time_column = "time",
    track_id_column = "id"
  )
}

test_that("event_fpt gives the correct errors", {
  x <- create_line_tracks()
  expect_error(
    event_fpt(data.frame(a = 1), as_units(1, "km")),
    "x must be a move2 object"
  )
  expect_error(
    event_fpt(example_tt, as_units(1, "km")),
    "x must be in a projected coordinate reference system"
  )
  no_crs <- x
  sf::st_crs(no_crs) <- NA
  expect_error(
    event_fpt(no_crs, as_units(1, "km")),
    "x must have a coordinate reference system"
  )
  expect_error(event_fpt(x, 1000), "radius must be a units object")
  expect_error(event_fpt(x, as_units(1, "h")), "radius must be a distance")
  expect_error(event_fpt(x, as_units(-1, "km")), "finite, positive")
  expect_error(
    event_fpt(x, as_units(c(1, 2), "km")),
    "radius must be a single value"
  )
  expect_error(event_fpt(x, as_units(1, "km"), units = "h"), "units must be")
  expect_error(
    event_fpt(x[rev(seq_len(nrow(x))), ], as_units(1, "km")),
    "x must be ordered by time"
  )
})

test_that("event_fpt interpolates the crossing times", {
  x <- create_line_tracks()
  # 1.5 km takes 150 s in each direction, and the circle of the events closer
  # than 1.5 km to the ends of the track is not left
  fpt <- event_fpt(x, as_units(1.5, "km"), units = as_units("s"))
  expect_identical(units::deparse_unit(fpt), "s")
  expect_equal(
    as.numeric(fpt),
    c(NA, NA, rep(300, 7), NA, NA)
  )
  # the units of the radius and of the result are converted
  expect_equal(
    as.numeric(event_fpt(x, as_units(1500, "m"), units = as_units("min"))),
    c(NA, NA, rep(5, 7), NA, NA)
  )
  # a radius of exactly one step is crossed at the next location
  expect_equal(
    as.numeric(event_fpt(x, as_units(1, "km"), units = as_units("s"))),
    c(NA, rep(200, 9), NA)
  )
})

test_that("event_fpt does not run across tracks", {
  x <- create_line_tracks(n = 6)
  y <- create_line_tracks(n = 6)
  y$id <- "b"
  two <- suppressWarnings(
    move2::mt_as_move2(
      rbind(
        as.data.frame(sf::st_drop_geometry(x)),
        as.data.frame(sf::st_drop_geometry(y))
      ) %>%
        dplyr::mutate(
          X = rep(sf::st_coordinates(x)[, 1], 2) +
            rep(c(0, 5000), each = 6),
          Y = 5000000
        ),
      coords = c("X", "Y"),
      crs = 32631,
      time_column = "time",
      track_id_column = "id"
    )
  )
  fpt <- as.numeric(
    event_fpt(two, as_units(1.5, "km"), units = as_units("s"))
  )
  expect_equal(fpt, rep(c(NA, NA, 300, 300, NA, NA), 2))
})

test_that("event_fpt ignores events without a location and dummy trips", {
  x <- create_line_tracks()
  x_empty <- x
  sf::st_geometry(x_empty)[3] <- sf::st_point()
  fpt <- as.numeric(
    event_fpt(x_empty, as_units(1.5, "km"), units = as_units("s"))
  )
  expect_true(is.na(fpt[3]))
  expect_equal(fpt[5:9], rep(300, 5))

  x_na <- x
  x_na$id <- "a_trip_na"
  x_na <- move2::mt_set_track_id_column(
    move2::mt_set_track_data(
      x_na,
      data.frame(id = "a_trip_na")
    ),
    "id"
  )
  expect_true(all(is.na(event_fpt(x_na, as_units(1.5, "km")))))
})

test_that("the FPT equals that of adehabitatLT, for any order of the radii", {
  skip_if_not_installed("adehabitatLT")
  set.seed(1)
  n <- 200
  df <- data.frame(
    x = 500000 + cumsum(stats::rnorm(n, 0, 500)),
    y = 5000000 + cumsum(stats::rnorm(n, 0, 500)),
    time = as.POSIXct("2024-01-01", tz = "UTC") +
      cumsum(stats::runif(n, 60, 600)),
    id = "a"
  )
  radii <- c(100, 500, 1000, 2500, 5000)
  ltraj <- adehabitatLT::as.ltraj(
    df[, c("x", "y")],
    date = df$time,
    id = df$id,
    typeII = TRUE
  )
  expected <- as.matrix(
    adehabitatLT::fpt(ltraj, radii = radii, units = "seconds")[[1]]
  )
  x <- move2::mt_as_move2(
    df,
    coords = c("x", "y"),
    crs = 32631,
    time_column = "time",
    track_id_column = "id"
  )
  for (i in seq_along(radii)) {
    expect_equal(
      as.numeric(
        event_fpt(x, as_units(radii[i], "m"), units = as_units("s"))
      ),
      unname(expected[, i])
    )
  }
  # all the radii at once, in the order that carries on the search
  expect_equal(
    fpt_matrix(x, radii),
    unname(expected)
  )
})
