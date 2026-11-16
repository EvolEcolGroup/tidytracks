# Stress test: alternating grids that are just too small and large enough.
# With move2utils 0.4.5 this usually crashes R within a few iterations
# ("caught segfault" or "malloc(): invalid next size"); with the fix, every
# call either succeeds or gives the "grid not large enough" error.
library(move2)
library(move2utils)
library(sf)
library(terra)

set.seed(2)
make_track <- function(id, n = 200) {
  data.frame(
    id = id,
    x = cumsum(rnorm(n, 0, 100)),
    y = cumsum(rnorm(n, 0, 100)),
    time = as.POSIXct("2024-01-01", tz = "UTC") +
      cumsum(round(rexp(n, 1 / 600)) + 1)
  )
}
df <- rbind(make_track("b"), make_track("a"))
x <- mt_as_move2(
  st_as_sf(df, coords = c("x", "y"), crs = 32630),
  time_column = "time", track_id_column = "id"
)

bb <- st_bbox(x)
w <- bb[["xmax"]] - bb[["xmin"]]
h <- bb[["ymax"]] - bb[["ymin"]]
grid <- function(res, k) {
  rast(
    xmin = bb[["xmin"]] - k * w, xmax = bb[["xmax"]] + k * w,
    ymin = bb[["ymin"]] - k * h, ymax = bb[["ymax"]] + k * h,
    resolution = res, crs = st_crs(x)$wkt
  )
}
grids <- rep(list(c(300, 1), c(150, 2), c(150, 1), c(75, 4)), 5)
for (i in seq_along(grids)) {
  g <- grids[[i]]
  result <- tryCatch({
    mt_dbbmm_ud(x, raster = grid(g[1], g[2]), location_error = 20,
                verbose = FALSE)
    "ok"
  }, error = function(e) "grid not large enough")
  # allocate and free memory, so that heap corruption is detected
  junk <- lapply(1:2000, function(j) rnorm(100))
  gc()
  message(i, ": res = ", g[1], ", extension = ", g[2], ": ", result)
}
message("finished without crashing")
