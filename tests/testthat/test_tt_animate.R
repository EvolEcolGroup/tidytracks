
skip_if_not_installed("gganimate")

# helper: build a minimal move2 object for lightweight tests ----
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

# Input validation
test_that("tt_animate errors if x is not a move2 object", {
  expect_error(tt_animate(data.frame()), "move2")
})

test_that("tt_animate errors if x has no CRS", {
  x_no_crs <- sf::st_set_crs(x, NA)
  expect_error(tt_animate(x_no_crs), "CRS")
})

test_that("tt_animate errors if basemap is not NULL or sf", {
  expect_error(tt_animate(x, basemap = "not_sf"), "basemap")
})

test_that("tt_animate errors if plot_lims is wrong length or type", {
  expect_error(tt_animate(x, plot_lims = c(0, 1, 2)), "plot_lims")
  expect_error(tt_animate(x, plot_lims = c("a", "b", "c", "d")), "plot_lims")
})

# Return value correctness with type = points
# n_frames matches unique datetimes, p_anim is a gganim object
test_that("n_frames and p_anim are correct with type = points", {
  result <- tt_animate(x, type = "points")
  expect_equal(result$n_frames, length(unique(x$date_time)))
  expect_s3_class(result$p_anim, "gganim")
})

# return value correctness with type = paths
test_that("n_frames and p_anim are correct with type = path", {
  result <- tt_animate(x, type = "paths")
  expect_equal(result$n_frames, length(unique(x$date_time)))
  expect_s3_class(result$p_anim, "gganim")
})

# NULL basemap
test_that("tt_animate works without a basemap", {
  result <- tt_animate(x, type = "points", basemap = NULL)
  expect_s3_class(result$p_anim, "gganim")
})

# custom plot_lims
test_that("tt_animate accepts custom plot_lims", {
  result <- tt_animate(x, type = "paths", plot_lims = c(-1, -1, 2, 2))
  expect_s3_class(result$p_anim, "gganim")
})

# test that label_format is embedded in the title expression ----
test_that("tt_animate embeds label_format in the title for type=points", {
  fmt <- "%b %e %H:%M"
  result <- tt_animate(make_test_tracks(), type = "points", label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
})

test_that("tt_animate embeds label_format in the title for type=paths", {
  fmt <- "%Y/%m/%d"
  result <- tt_animate(make_test_tracks(), type = "paths", label_format = fmt)
  expect_true(grepl(fmt, result$p_anim$labels$title, fixed = TRUE))
})

# for manual testing only: animate the gganim using av_renderer()
# gganimate::animate(plot = result$p_anim,
#                    nframes = result$n_frames,
#                    fps = 10,
#                    # renderer = gganimate::av_renderer()
#                    renderer = gganimate::gifski_renderer()
#                    )
