# move2 objects can have a geometry column with any name (e.g. "geom" when the
# data were read from a GeoPackage); create a copy of `x` (example_tt) with
# the geometry column named "geom"
make_geom_tt <- function(x) {
  coords <- sf::st_coordinates(x)
  events <- data.frame(
    track_id = x$track_id,
    date_time = x$date_time,
    x = coords[, "X"],
    y = coords[, "Y"]
  )
  events <- sf::st_as_sf(
    events,
    coords = c("x", "y"),
    crs = sf::st_crs(x)
  )
  events <- dplyr::rename(events, geom = "geometry")
  geom_tt <- move2::mt_as_move2(
    events,
    time_column = "date_time",
    track_id_column = "track_id"
  )
  show_meta(geom_tt) <- show_meta(x)
  geom_tt
}

test_that("functions work with a geometry column not called geometry", {
  geom_tt <- make_geom_tt(example_tt)
  expect_equal(attr(geom_tt, "sf_column"), "geom")

  expect_equal(event_distance(geom_tt), event_distance(example_tt))
  expect_equal(event_speed(geom_tt), event_speed(example_tt))

  max_speed <- as_units(50, "km/h")
  expect_equal(
    event_flag_mcconnell(geom_tt, max_speed = max_speed),
    event_flag_mcconnell(example_tt, max_speed = max_speed)
  )
  expect_equal(
    nrow(tt_clean_mcconnell(geom_tt, max_speed = max_speed)),
    nrow(tt_clean_mcconnell(example_tt, max_speed = max_speed))
  )

  expect_equal(
    track_summary_stats(geom_tt),
    track_summary_stats(example_tt)
  )

  expect_equal(
    as.data.frame(geom_tt, include_meta = TRUE, drop_geometry = TRUE),
    as.data.frame(example_tt, include_meta = TRUE, drop_geometry = TRUE)
  )
})

test_that("tt_write_data works with a geometry column not called geometry", {
  geom_tt <- make_geom_tt(example_tt)
  prefix_geom <- file.path(tempdir(), "geom_tt")
  prefix_example <- file.path(tempdir(), "example_tt")
  on.exit(unlink(paste0(
    c(prefix_geom, prefix_example),
    rep(c("_events.csv", "_metadata.csv"), each = 2)
  )))

  tt_write_data(geom_tt, prefix_geom)
  tt_write_data(example_tt, prefix_example)
  expect_identical(
    readLines(paste0(prefix_geom, "_events.csv")),
    readLines(paste0(prefix_example, "_events.csv"))
  )
})

test_that("geom_event_path works with a geometry column not called geometry", {
  geom_tt <- make_geom_tt(example_tt)
  layer_data <- function(x) {
    p <- ggplot2::ggplot() + geom_event_path(data = x)
    p$layers[[1]]$data
  }

  geom_steps <- layer_data(geom_tt)
  example_steps <- layer_data(example_tt)
  expect_equal(nrow(geom_steps), nrow(example_steps))
  expect_true(nrow(geom_steps) > 0)
  expect_true(all(sf::st_geometry_type(geom_steps) == "LINESTRING"))
})

test_that("tt_regular_time keeps the name of the geometry column", {
  geom_tt <- make_geom_tt(example_tt)
  resampled <- tt_regular_time(geom_tt, interval = as_units(10, "min"))
  expect_equal(attr(resampled, "sf_column"), "geom")
  expect_equal(
    sf::st_coordinates(resampled),
    sf::st_coordinates(
      tt_regular_time(example_tt, interval = as_units(10, "min"))
    )
  )
})
