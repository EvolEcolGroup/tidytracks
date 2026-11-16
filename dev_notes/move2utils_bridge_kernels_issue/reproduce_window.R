# Deterministic reproduction: a grid accepted by mt_dbbmm_ud() although a
# bridge window ends one column past the grid (out-of-bounds write in C).
library(move2)
library(move2utils)
library(sf)
library(terra)

set.seed(1)
n <- 100
df <- data.frame(
  id = "a",
  x = cumsum(rnorm(n, 0, 100)),
  y = cumsum(rnorm(n, 0, 100)),
  time = as.POSIXct("2024-01-01", tz = "UTC") + (seq_len(n) - 1) * 600
)
trk <- mt_as_move2(
  st_as_sf(df, coords = c("x", "y"), crs = 32630),
  time_column = "time", track_id_column = "id"
)
v <- mt_dbbmm_variance(trk, location_error = 20, window_size = 31, margin = 11)

# Replicates the window computed for each time step by dbbmm2_omp()
# (src/bgb_bbmm_omp.c), with the arguments passed by
# mt_dbbmm_ud.mt_dbbmm_variance() (time_step = NULL, ext = 4).
kernel_windows <- function(v, grid) {
  td <- v$track_data
  t <- td$time_mins - min(td$time_mins)
  s <- c(v$variance, 0)
  s[is.na(s)] <- 0
  le <- td$location_error
  x_grid <- xFromCol(grid, seq_len(ncol(grid)))
  y_grid <- yFromRow(grid, rev(seq_len(nrow(grid))))
  x0 <- x_grid[1]
  y0 <- y_grid[1]
  x_res <- x_grid[2] - x_grid[1]
  y_res <- y_grid[2] - y_grid[1]
  n_y <- length(y_grid)
  d_t <- min(diff(t)) / 15
  n_loc <- length(t)
  out <- list()
  k <- 1
  ti <- t[1] + ((t[n_loc] - t[1]) %% d_t) / 2
  while (ti <= t[n_loc]) {
    while (t[k + 1] < ti) k <- k + 1
    if (v$interest[k]) {
      a <- (ti - t[k]) / (t[k + 1] - t[k])
      mux <- td$x[k] + (td$x[k + 1] - td$x[k]) * a
      muy <- td$y[k] + (td$y[k + 1] - td$y[k]) * a
      sigma <- (t[k + 1] - t[k]) * a * (1 - a) * s[k] +
        (1 - a)^2 * le[k]^2 + a^2 * le[k + 1]^2
      ext <- sqrt(sigma) * 4
      out[[length(out) + 1]] <- c(
        x_start = floor((mux - x0) / x_res - ext / x_res),
        x_end = ceiling((mux - x0) / x_res + ext / x_res),
        y_start = n_y - ceiling((muy - y0) / y_res + ext / y_res),
        y_end = n_y - floor((muy - y0) / y_res - ext / y_res)
      )
    }
    ti <- ti + d_t
  }
  do.call(rbind, out)
}

res <- 50
bb <- st_bbox(trk)
# a grid wide enough on all sides, to find the largest window index
wide <- rast(
  xmin = bb[["xmin"]] - 2000, xmax = bb[["xmax"]] + 2000,
  ymin = bb[["ymin"]] - 2000, ymax = bb[["ymax"]] + 2000,
  resolution = res, crs = st_crs(trk)$wkt
)
x_end_max <- max(kernel_windows(v, wide)[, "x_end"])

# the same grid, cut so that it has exactly x_end_max columns: the largest
# window then ends at column index ncol (0-based), one past the last column
tight <- rast(
  xmin = xmin(wide), xmax = xmin(wide) + x_end_max * res,
  ymin = ymin(wide), ymax = ymax(wide),
  resolution = res, crs = st_crs(trk)$wkt
)
w <- kernel_windows(v, tight)
cat("columns in grid:", ncol(tight), "\n")
cat("largest x_end of a window:", max(w[, "x_end"]), "\n")
cat("time steps whose window reaches column index ncol:",
    sum(w[, "x_end"] == ncol(tight)), "\n")

ud <- tryCatch(
  mt_dbbmm_ud(v, raster = tight, verbose = FALSE),
  error = function(e) e
)
if (inherits(ud, "error")) {
  cat("mt_dbbmm_ud() gave an error:", conditionMessage(ud), "\n")
} else {
  cat("mt_dbbmm_ud() returned without error, although the loop wrote",
      "past the end of the output matrix\n")
}

# sanity check of the replicated windows: with one column fewer, the largest
# window ends beyond ncol, and mt_dbbmm_ud() does give an error
tighter <- rast(
  xmin = xmin(wide), xmax = xmin(wide) + (x_end_max - 1) * res,
  ymin = ymin(wide), ymax = ymax(wide),
  resolution = res, crs = st_crs(trk)$wkt
)
cat("with", ncol(tighter), "columns:",
    tryCatch({
      mt_dbbmm_ud(v, raster = tighter, verbose = FALSE)
      "no error"
    }, error = conditionMessage), "\n")
