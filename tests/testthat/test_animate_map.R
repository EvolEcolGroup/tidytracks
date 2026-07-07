
skip_if_not_installed("gganimate")

# helper: build a minimal move2 object ----
make_test_tracks <- function(crs = 4326) {
  times <- seq(
    as.POSIXct("2023-01-01 00:00:00", tz = "UTC"),
    by = "10 mins", length.out = 10
  )
  df <- data.frame(
    bird_id   = rep(c("A", "B"), each = 10),
    date_time = rep(times, 2),
    x = c(seq(0, 1, length.out = 10), seq(0.5, 1.5, length.out = 10)),
    y = c(seq(0, 1, length.out = 10), seq(0.5, 1.5, length.out = 10))
  )
  sf_df <- sf::st_as_sf(df, coords = c("x", "y"), crs = crs)
  move2::mt_as_move2(sf_df, track_id_column = "bird_id",
                     time_column = "date_time")
}

x <- make_test_tracks()

# helpers: minimal ggplots using the tt geoms ----
make_paths_map <- function(x) {
  ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id), linewidth = 2)
}

make_points_map <- function(x) {
  ggplot2::ggplot() +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id), size = 3)
}

# ===========================================================================
# geom_event_path (drop_final_point = TRUE)
# ===========================================================================

test_that("geom_event_path errors if data is NULL", {
  expect_error(geom_event_path(), "data must be specified")
})

test_that("geom_event_path errors if data is not a move2 object", {
  expect_error(geom_event_path(data = data.frame()), "move2")
})

test_that("geom_event_path can be added to a ggplot without error", {
  expect_no_error(
    ggplot2::ggplot() + geom_event_path(data = x, ggplot2::aes(colour = bird_id))
  )
})

test_that("geom_event_path with drop_final_point = TRUE contains only LINESTRING geometries", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id), drop_final_point = TRUE)
  layer_data <- p$layers[[1]]$data
  geom_types <- unique(as.character(sf::st_geometry_type(layer_data)))
  expect_equal(geom_types, "LINESTRING")
})

test_that("geom_event_path with drop_final_point = TRUE has n_events - n_tracks rows", {
  # (because the final point of each of track is not included)
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id), drop_final_point = TRUE)
  layer_data <- p$layers[[1]]$data
  n_tracks <- length(unique(x[[move2::mt_track_id_column(x)]]))
  expect_equal(nrow(layer_data), nrow(x) - n_tracks)
})

test_that("geom_event_path layer data preserves track ID and datetime columns", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id))
  layer_data <- p$layers[[1]]$data
  expect_true(move2::mt_track_id_column(x) %in% names(layer_data))
  expect_true(move2::mt_time_column(x) %in% names(layer_data))
})

# ===========================================================================
# tt_detect_layer_type — tidytracks_geom attribute retention and detection
# ===========================================================================

test_that("geom_event_path retains tidytracks_geom attribute in layer data", {
  p <- make_paths_map(x)
  layer_data <- p$layers[[1]]$data
  expect_equal(attr(layer_data, "tidytracks_geom"), "event_path")
})

test_that("geom_event_point retains tidytracks_geom attribute in layer data", {
  p <- make_points_map(x)
  layer_data <- p$layers[[1]]$data
  expect_equal(attr(layer_data, "tidytracks_geom"), "event_point")
})

test_that("geom_event_path retains tidytracks_data_name attribute matching the object name", {
  p <- make_paths_map(x)
  layer_data <- p$layers[[1]]$data
  expect_equal(attr(layer_data, "tidytracks_data_name"), "x")
})

test_that("geom_event_point retains tidytracks_data_name attribute matching the object name", {
  p <- make_points_map(x)
  layer_data <- p$layers[[1]]$data
  expect_equal(attr(layer_data, "tidytracks_data_name"), "x")
})

test_that("tt_detect_layer_type returns NULL for an empty plot", {
  expect_null(tt_detect_layer_type(ggplot2::ggplot()))
})

test_that("tt_detect_layer_type returns NULL when only static sf layers are present", {
  colony_sf <- sf::st_sf(
    name = "colony",
    geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
  )
  p <- ggplot2::ggplot() + ggplot2::geom_sf(data = colony_sf)
  expect_null(tt_detect_layer_type(p))
})

test_that("tt_detect_layer_type returns type 'path' for a geom_event_path layer", {
  result <- tt_detect_layer_type(make_paths_map(x))
  expect_equal(result$type, "path")
})

test_that("tt_detect_layer_type returns type 'point' for a geom_event_point layer", {
  result <- tt_detect_layer_type(make_points_map(x))
  expect_equal(result$type, "point")
})

test_that("tt_detect_layer_type returns the correct time_col for a path layer", {
  result <- tt_detect_layer_type(make_paths_map(x))
  expect_equal(result$time_col, move2::mt_time_column(x))
})

test_that("tt_detect_layer_type returns the correct time_col for a point layer", {
  result <- tt_detect_layer_type(make_points_map(x))
  expect_equal(result$time_col, move2::mt_time_column(x))
})

test_that("tt_detect_layer_type ignores a static sf layer before the track layer", {
  colony_sf <- sf::st_sf(
    name = "colony",
    geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
  )
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = colony_sf) +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id))
  result <- tt_detect_layer_type(p)
  expect_equal(result$type, "path")
})

test_that("tt_detect_layer_type ignores a static sf layer after the track layer", {
  colony_sf <- sf::st_sf(
    name = "colony",
    geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
  )
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    ggplot2::geom_sf(data = colony_sf)
  result <- tt_detect_layer_type(p)
  expect_equal(result$type, "path")
})

test_that("tt_detect_layer_type warns when multiple track layers are present", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
  expect_warning(tt_detect_layer_type(p), "Multiple")
})

test_that("tt_detect_layer_type warning mentions layer_to_animate", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
  expect_warning(tt_detect_layer_type(p), "layer_to_animate")
})

test_that("tt_detect_layer_type returns the first track layer when multiple are present", {
  # path is added first, so it should be returned despite the warning
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
  result <- suppressWarnings(tt_detect_layer_type(p))
  expect_equal(result$type, "path")
})

test_that("tt_detect_layer_type selects the correct layer by name", {
  # Two move2 objects with identical timestamps; x2 is a point layer added second
  x2 <- x
  p <- ggplot2::ggplot() +
    geom_event_path(data = x,  ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x2, ggplot2::aes(colour = bird_id))
  result <- tt_detect_layer_type(p, layer_name = "x2")
  expect_equal(result$type, "point")
})

test_that("tt_detect_layer_type errors if layer_name does not match any layer", {
  p <- make_paths_map(x)
  expect_error(tt_detect_layer_type(p, layer_name = "nonexistent"), "nonexistent")
})

test_that("animate_map errors if layer_to_animate is not a move2 object", {
  p <- make_paths_map(x)
  expect_error(animate_map(p, layer_to_animate = data.frame()), "move2")
})

test_that("animate_map with layer_to_animate suppresses the multiple-layers warning", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x,  ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
  expect_no_warning(animate_map(p, layer_to_animate = x))
})

test_that("animate_map with layer_to_animate selects the named layer", {
  x2 <- x
  p <- ggplot2::ggplot() +
    geom_event_path(data = x,  ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x2, ggplot2::aes(colour = bird_id))
  # Without layer_to_animate, path (first layer) would be animated; here we
  # explicitly request the point layer
  result <- animate_map(p, layer_to_animate = x2)
  expect_s3_class(result, "gganim")
  # n_timesteps for a point layer equals all unique timestamps (no rows dropped)
  expect_equal(attr(result, "n_timesteps"), length(unique(x2$date_time)))
})

# ===========================================================================
# animate_map — input validation
# ===========================================================================

test_that("animate_map errors if p is not a ggplot", {
  expect_error(animate_map("not_a_plot"), "ggplot")
})

test_that("animate_map errors if wake_length is out of range", {
  p <- make_paths_map(x)
  expect_error(animate_map(p, wake_length = 0),    "wake_length")
  expect_error(animate_map(p, wake_length = -0.1), "wake_length")
  expect_error(animate_map(p, wake_length = 1.5),  "wake_length")
})

test_that("animate_map errors if wake_length is non-numeric", {
  expect_error(animate_map(make_paths_map(x), wake_length = "half"), "wake_length")
})

test_that("animate_map errors if no supported track layer is found", {
  expect_error(animate_map(ggplot2::ggplot()), "No supported track layer")
})

test_that("animate_map warns when multiple track layers are present", {
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
  expect_warning(animate_map(p), "Multiple")
})

test_that("animate_map warns and animates the first layer in the stack when layer_to_animate is not given", {
  # x_fewer has fewer time steps than x, so n_timesteps reveals which was used.
  # x is added first (path), x_fewer second (point).
  x_fewer <- make_test_tracks() |> dplyr::slice(1:5)
  p <- ggplot2::ggplot() +
    geom_event_path(data = x,        ggplot2::aes(colour = bird_id)) +
    geom_event_point(data = x_fewer, ggplot2::aes(colour = bird_id))
  result <- NULL
  expect_warning(result <- animate_map(p), "Multiple")
  # path layer drops the final event per track (2 tracks, 10 rows -> 8 unique times)
  expect_equal(attr(result, "n_timesteps"), length(unique(x$date_time)) - 1L)
})

# ===========================================================================
# animate_map — path animation
# ===========================================================================

test_that("animate_map with path layer returns a gganim object", {
  expect_s3_class(animate_map(make_paths_map(x)), "gganim")
})

test_that("animate_map with path layer attaches n_timesteps as an attribute", {
  result <- animate_map(make_paths_map(x))
  expect_false(is.null(attr(result, "n_timesteps")))
})

test_that("animate_map with path layer: n_timesteps reflects dropped final events", {
  result <- animate_map(make_paths_map(x))
  # geom_event_path drops the final event of each track, so n_timesteps should
  # equal the number of unique timestamps in x minus those that only appear
  # as a final event. In the test data both tracks share the same timestamps,
  # so the last timestamp is dropped entirely: n_timesteps == n_unique_times - 1.
  expect_equal(attr(result, "n_timesteps"), length(unique(x$date_time)) - 1L)
})

test_that("animate_map with path layer: custom wake_length produces a gganim object", {
  expect_s3_class(animate_map(make_paths_map(x), wake_length = 0.3), "gganim")
})

test_that("animate_map with path layer: wake_length < 1 uses a shadow_wake_build", {
  result <- animate_map(make_paths_map(x), wake_length = 0.3)
  expect_true(inherits(result$shadow, "ShadowWakeBuild"))
})

test_that("animate_map with path layer: wake_length = 1 produces a gganim object", {
  expect_s3_class(animate_map(make_paths_map(x), wake_length = 1), "gganim")
})

test_that("animate_map with path layer: wake_length = 1 uses shadow_mark (no fading)", {
  result <- animate_map(make_paths_map(x), wake_length = 1)
  expect_true(inherits(result$shadow, "ShadowMark"))
})

test_that("animate_map with path layer embeds label_format in title", {
  fmt <- "%Y/%m/%d"
  result <- animate_map(make_paths_map(x), label_format = fmt)
  expect_true(grepl(fmt, result$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$labels$title, fixed = TRUE))
})

test_that("animate_map with path layer works when piped from a ggplot", {
  expect_s3_class(make_paths_map(x) |> animate_map(), "gganim")
})

# ===========================================================================
# animate_map — point animation
# ===========================================================================

test_that("animate_map with point layer returns a gganim object", {
  expect_s3_class(animate_map(make_points_map(x)), "gganim")
})

test_that("animate_map with point layer attaches n_timesteps as an attribute", {
  result <- animate_map(make_points_map(x))
  expect_false(is.null(attr(result, "n_timesteps")))
})

test_that("animate_map with point layer: n_timesteps matches unique datetimes", {
  result <- animate_map(make_points_map(x))
  expect_equal(attr(result, "n_timesteps"), length(unique(x$date_time)))
})

test_that("animate_map with point layer embeds label_format in title", {
  fmt <- "%b %e %H:%M"
  result <- animate_map(make_points_map(x), label_format = fmt)
  expect_true(grepl(fmt, result$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$labels$title, fixed = TRUE))
})

test_that("animate_map with point layer works when piped from a ggplot", {
  expect_s3_class(make_points_map(x) |> animate_map(), "gganim")
})

test_that("animate_map with point layer: wake_length < 1 uses a shadow_wake_build", {
  result <- animate_map(make_points_map(x), wake_length = 0.3)
  expect_true(inherits(result$shadow, "ShadowWakeBuild"))
})

test_that("animate_map with point layer: wake_length = 1 produces a gganim object", {
  expect_s3_class(animate_map(make_points_map(x), wake_length = 1), "gganim")
})

test_that("animate_map with point layer: wake_length = 1 uses shadow_mark (no fading)", {
  result <- animate_map(make_points_map(x), wake_length = 1)
  expect_true(inherits(result$shadow, "ShadowMark"))
})

# for manual testing only (uncomment both lines together):
# result <- make_paths_map(x) |> animate_map()
# gganimate::animate(result, nframes = attr(result, "n_timesteps"), fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_paths_map(x) |> animate_map(wake_length = 1)
# gganimate::animate(result, nframes = attr(result, "n_timesteps"), fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_points_map(x) |> animate_map()
# gganimate::animate(result, nframes = attr(result, "n_timesteps"), fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_points_map(x) |> animate_map(wake_length = 1)
# gganimate::animate(result, nframes = attr(result, "n_timesteps"), fps = 2,
#                    renderer = gganimate::gifski_renderer())
