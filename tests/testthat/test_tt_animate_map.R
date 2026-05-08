
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
    geom_event_path(data = x, ggplot2::aes(colour = bird_id), linewidth = 1)
}

make_points_map <- function(x) {
  ggplot2::ggplot() +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
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
# tt_animate_map — input validation
# ===========================================================================

test_that("tt_animate_map errors if p is not a ggplot", {
  expect_error(tt_animate_map("not_a_plot", x), "ggplot")
})

test_that("tt_animate_map errors if x is not a move2 object", {
  expect_error(tt_animate_map(make_paths_map(x), data.frame()), "move2")
})

test_that("tt_animate_map errors if fade is not logical", {
  expect_error(tt_animate_map(make_paths_map(x), x, fade = "yes"), "fade")
})

test_that("tt_animate_map errors if wake_length is out of range", {
  p <- make_paths_map(x)
  expect_error(tt_animate_map(p, x, wake_length = 0),    "wake_length")
  expect_error(tt_animate_map(p, x, wake_length = -0.1), "wake_length")
  expect_error(tt_animate_map(p, x, wake_length = 1.5),  "wake_length")
})

test_that("tt_animate_map errors if wake_length is non-numeric", {
  expect_error(tt_animate_map(make_paths_map(x), x, wake_length = "half"),
               "wake_length")
})

test_that("tt_animate_map errors if no supported track layer is found", {
  p_empty <- ggplot2::ggplot()
  expect_error(tt_animate_map(p_empty, x), "No supported track layer")
})

test_that("tt_animate_map ignores static sf point layers when detecting track type", {
  # A static colony point: POINT geometry but no time column
  colony_sf <- sf::st_sf(
    name = "colony",
    geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
  )
  # Static POINT layer added before the path layer — must not be misdetected
  p <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = colony_sf) +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id))
  result <- tt_animate_map(p, x)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_map ignores static sf point layers added after the track layer", {
  colony_sf <- sf::st_sf(
    name = "colony",
    geometry = sf::st_sfc(sf::st_point(c(0.5, 0.5)), crs = 4326)
  )
  p <- ggplot2::ggplot() +
    geom_event_path(data = x, ggplot2::aes(colour = bird_id)) +
    ggplot2::geom_sf(data = colony_sf)
  result <- tt_animate_map(p, x)
  expect_s3_class(result$p_anim, "gganim")
})

# ===========================================================================
# tt_animate_map — path animation
# ===========================================================================

test_that("tt_animate_map with path layer returns named list with p_anim and n_timesteps", {
  result <- tt_animate_map(make_paths_map(x), x)
  expect_type(result, "list")
  expect_named(result, c("p_anim", "n_timesteps"))
})

test_that("tt_animate_map with path layer returns a gganim object", {
  result <- tt_animate_map(make_paths_map(x), x)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_map with path layer: n_timesteps reflects dropped final events", {
  result <- tt_animate_map(make_paths_map(x), x)
  # geom_event_path drops the final event of each track, so n_timesteps should
  # equal the number of unique timestamps in x minus those that only appear
  # as a final event. In the test data both tracks share the same timestamps,
  # so the last timestamp is dropped entirely: n_timesteps == n_unique_times - 1.
  expect_equal(result$n_timesteps, length(unique(x$date_time)) - 1L)
})

test_that("tt_animate_map with path layer: fade = TRUE produces a gganim object", {
  result <- tt_animate_map(make_paths_map(x), x, fade = TRUE, wake_length = 0.3)
  expect_s3_class(result$p_anim, "gganim")
  # when running these tests manually, animate this result to check it
})

test_that("tt_animate_map with path layer: fade = FALSE produces a gganim object", {
  result <- tt_animate_map(make_paths_map(x), x, fade = FALSE)
  expect_s3_class(result$p_anim, "gganim")
  # when running these tests manually, animate this result to check it
})

test_that("tt_animate_map with path layer embeds label_format in title", {
  fmt <- "%Y/%m/%d"
  result <- tt_animate_map(make_paths_map(x), x, label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$p_anim$labels$title, fixed = TRUE))
})

test_that("tt_animate_map with path layer works when piped from a ggplot", {
  result <- make_paths_map(x) |> tt_animate_map(x)
  expect_s3_class(result$p_anim, "gganim")
})

# ===========================================================================
# tt_animate_map — point animation
# ===========================================================================

test_that("tt_animate_map with point layer returns named list with p_anim and n_timesteps", {
  result <- tt_animate_map(make_points_map(x), x)
  expect_type(result, "list")
  expect_named(result, c("p_anim", "n_timesteps"))
})

test_that("tt_animate_map with point layer returns a gganim object", {
  result <- tt_animate_map(make_points_map(x), x)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_map with point layer: n_timesteps matches unique datetimes", {
  result <- tt_animate_map(make_points_map(x), x)
  expect_equal(result$n_timesteps, length(unique(x$date_time)))
})

test_that("tt_animate_map with point layer embeds label_format in title", {
  fmt <- "%b %e %H:%M"
  result <- tt_animate_map(make_points_map(x), x, label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$p_anim$labels$title, fixed = TRUE))
})

test_that("tt_animate_map with point layer works when piped from a ggplot", {
  result <- make_points_map(x) |> tt_animate_map(x)
  expect_s3_class(result$p_anim, "gganim")
})

# for manual testing only (uncomment both lines together):
# result <- make_paths_map(x) |> tt_animate_map(x, fade = TRUE)
# gganimate::animate(result$p_anim, nframes = result$n_timesteps, fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_paths_map(x) |> tt_animate_map(x, fade = FALSE)
# gganimate::animate(result$p_anim, nframes = result$n_timesteps, fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_points_map(x) |> tt_animate_map(x)
# gganimate::animate(result$p_anim, nframes = result$n_timesteps, fps = 2,
#                    renderer = gganimate::gifski_renderer())
