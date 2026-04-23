
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
    ggplot2::geom_sf(data = tt_event_segments(x),
                     ggplot2::aes(colour = bird_id), linewidth = 1)
}

make_points_map <- function(x) {
  ggplot2::ggplot() +
    geom_event_point(data = x, ggplot2::aes(colour = bird_id))
}

# ===========================================================================
# tt_event_segments
# ===========================================================================

test_that("tt_event_segments errors if x is not a move2 object", {
  expect_error(tt_event_segments(data.frame()), "move2")
})

test_that("tt_event_segments returns an sf object", {
  segs <- tt_event_segments(x)
  expect_true(inherits(segs, "sf"))
})

test_that("tt_event_segments returns only LINESTRING geometries", {
  segs <- tt_event_segments(x)
  geom_types <- unique(as.character(sf::st_geometry_type(segs)))
  expect_equal(geom_types, "LINESTRING")
})

test_that("tt_event_segments returns n_events - n_tracks rows", {
  segs <- tt_event_segments(x)
  n_tracks <- length(unique(x[[move2::mt_track_id_column(x)]]))
  expect_equal(nrow(segs), nrow(x) - n_tracks)
})

test_that("tt_event_segments preserves track ID and datetime columns", {
  segs <- tt_event_segments(x)
  expect_true(move2::mt_track_id_column(x) %in% names(segs))
  expect_true(move2::mt_time_column(x) %in% names(segs))
})

# ===========================================================================
# tt_animate_paths
# ===========================================================================

# Input validation ----

test_that("tt_animate_paths errors if p is not a ggplot", {
  expect_error(tt_animate_paths("not_a_plot", x), "ggplot")
})

test_that("tt_animate_paths errors if x is not a move2 object", {
  expect_error(tt_animate_paths(make_paths_map(x), data.frame()), "move2")
})

test_that("tt_animate_paths errors if fade is not logical", {
  expect_error(tt_animate_paths(make_paths_map(x), x, fade = "yes"), "fade")
})

test_that("tt_animate_paths errors if wake_length is out of range", {
  p <- make_paths_map(x)
  expect_error(tt_animate_paths(p, x, wake_length = 0),    "wake_length")
  expect_error(tt_animate_paths(p, x, wake_length = -0.1), "wake_length")
  expect_error(tt_animate_paths(p, x, wake_length = 1.5),  "wake_length")
})

# Return value ----

test_that("tt_animate_paths returns a named list with p_anim and n_frames", {
  result <- tt_animate_paths(make_paths_map(x), x)
  expect_type(result, "list")
  expect_named(result, c("p_anim", "n_frames"))
})

test_that("tt_animate_paths p_anim is a gganim object", {
  result <- tt_animate_paths(make_paths_map(x), x)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_paths n_frames matches unique datetimes in x", {
  result <- tt_animate_paths(make_paths_map(x), x)
  expect_equal(result$n_frames, length(unique(x$date_time)))
})

# fade parameter ----

test_that("tt_animate_paths fade = TRUE produces a gganim object", {
  result <- tt_animate_paths(make_paths_map(x), x, fade = TRUE, wake_length = 0.3)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_paths fade = FALSE produces a gganim object", {
  result <- tt_animate_paths(make_paths_map(x), x, fade = FALSE)
  expect_s3_class(result$p_anim, "gganim")
})

# label_format ----

test_that("tt_animate_paths embeds label_format and frame_time in title", {
  fmt <- "%Y/%m/%d"
  result <- tt_animate_paths(make_paths_map(x), x, label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$p_anim$labels$title, fixed = TRUE))
})

# Pipe-friendliness ----

test_that("tt_animate_paths works when piped from a ggplot", {
  result <- make_paths_map(x) |> tt_animate_paths(x)
  expect_s3_class(result$p_anim, "gganim")
})

# ===========================================================================
# tt_animate_points
# ===========================================================================

# Input validation ----

test_that("tt_animate_points errors if p is not a ggplot", {
  expect_error(tt_animate_points("not_a_plot", x), "ggplot")
})

test_that("tt_animate_points errors if x is not a move2 object", {
  expect_error(tt_animate_points(make_points_map(x), data.frame()), "move2")
})

test_that("tt_animate_points errors if wake_length is out of range", {
  p <- make_points_map(x)
  expect_error(tt_animate_points(p, x, wake_length = 0),    "wake_length")
  expect_error(tt_animate_points(p, x, wake_length = -0.1), "wake_length")
  expect_error(tt_animate_points(p, x, wake_length = 1.5),  "wake_length")
})

test_that("tt_animate_points errors if wake_length is non-numeric", {
  expect_error(tt_animate_points(make_points_map(x), x, wake_length = "half"),
               "wake_length")
})

# Return value ----

test_that("tt_animate_points returns a named list with p_anim and n_frames", {
  result <- tt_animate_points(make_points_map(x), x)
  expect_type(result, "list")
  expect_named(result, c("p_anim", "n_frames"))
})

test_that("tt_animate_points p_anim is a gganim object", {
  result <- tt_animate_points(make_points_map(x), x)
  expect_s3_class(result$p_anim, "gganim")
})

test_that("tt_animate_points n_frames matches unique datetimes in x", {
  result <- tt_animate_points(make_points_map(x), x)
  expect_equal(result$n_frames, length(unique(x$date_time)))
})

# label_format ----

test_that("tt_animate_points embeds label_format and frame_time in title", {
  fmt <- "%b %e %H:%M"
  result <- tt_animate_points(make_points_map(x), x, label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
  expect_true(grepl("frame_time", result$p_anim$labels$title, fixed = TRUE))
})

# Pipe-friendliness ----

test_that("tt_animate_points works when piped from a ggplot", {
  result <- make_points_map(x) |> tt_animate_points(x)
  expect_s3_class(result$p_anim, "gganim")
})

# for manual testing only (uncomment both lines together):
# result <- make_paths_map(x) |> tt_animate_paths(x, fade = TRUE)
# gganimate::animate(result$p_anim, nframes = result$n_frames, fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_paths_map(x) |> tt_animate_paths(x, fade = FALSE)
# gganimate::animate(result$p_anim, nframes = result$n_frames, fps = 2,
#                    renderer = gganimate::gifski_renderer())
#
# result <- make_points_map(x) |> tt_animate_points(x)
# gganimate::animate(result$p_anim, nframes = result$n_frames, fps = 2,
#                    renderer = gganimate::gifski_renderer())
