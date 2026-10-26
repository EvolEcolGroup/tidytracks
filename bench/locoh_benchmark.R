# Benchmark of hr_tt_locoh() (Rcpp implementation) against amt::hr_locoh()
#
# Run from the root of the package, with tidytracks installed (or loaded with
# devtools::load_all()) and amt and bench available:
#   Rscript bench/locoh_benchmark.R
#
# For each data set and each type of LoCoH, the script:
#   1. checks that both implementations give the same home ranges (the
#      relative difference in area between the two, for each level);
#   2. times both implementations with bench::mark().
# amt buffers every hull by 1e-5 (its `rand_buffer`), so hr_tt_locoh() is run
# with `buffer = 1e-5` to compare like with like; the timings of the default
# (`buffer = 0`) are reported as well.

library(tidytracks)
library(amt)
library(bench)

set.seed(42)
levels <- c(0.5, 0.95)

# Simulate a track that stays within a home range: a random walk pulled back
# towards the origin (an Ornstein-Uhlenbeck process), in metres, with two
# centres of activity so that the home range has a non-trivial shape.
simulate_track <- function(n_locations) {
  xy <- matrix(0, n_locations, 2)
  centres <- rbind(c(0, 0), c(3000, 1500))
  centre <- 1
  for (i in 2:n_locations) {
    # switch to the other centre now and then
    if (stats::runif(1) < 0.01) {
      centre <- 3 - centre
    }
    pull <- 0.05 * (centres[centre, ] - xy[i - 1, ])
    xy[i, ] <- xy[i - 1, ] + pull + stats::rnorm(2, sd = 100)
  }
  data.frame(
    x = xy[, 1] + 500000,
    y = xy[, 2] + 4000000,
    time = as.POSIXct("2024-01-01", tz = "UTC") + seq_len(n_locations) * 3600,
    id = "sim"
  )
}

# Turn a data frame of locations into the inputs of both packages: a move2
# object for tidytracks and a track_xy for amt (built outside the timings).
make_inputs <- function(df, crs) {
  tt <- move2::mt_as_move2(
    sf::st_as_sf(df, coords = c("x", "y"), crs = crs),
    time_column = "time",
    track_id_column = "id"
  )
  trk <- amt::make_track(df, x, y, crs = crs) # nolint: object_usage_linter.
  list(tt = tt, trk = trk)
}

# the data sets: one real track (a wild boar from adehabitatHR, as stored in
# the test data of tidytracks) and simulated tracks of increasing length
boar <- readRDS("tests/testthat/testdata/wildboar_tt.rds")
boar <- boar[move2::mt_track_id(boar) == "Brock", ]
boar_xy <- sf::st_coordinates(boar)
datasets <- list(
  boar_brock = data.frame(
    x = boar_xy[, 1],
    y = boar_xy[, 2],
    time = move2::mt_time(boar),
    id = "Brock"
  )
)
for (n_locations in c(500, 1000, 2000, 5000)) {
  datasets[[paste0("sim_", n_locations)]] <- simulate_track(n_locations)
}
crs <- sf::st_crs(boar)

# The parameter for each type: 10 neighbours for "k"; for "r" and "a", values
# scaled to the data (the median distance to the 10th nearest neighbour, and
# 10 times that), so that the hulls have a similar number of points.
locoh_params <- function(df) {
  # FNN is a dependency of amt
  d10 <- FNN::get.knn(df[, c("x", "y")], k = 10)$nn.dist[, 10]
  c(k = 10, r = stats::median(d10), a = 10 * stats::median(d10))
}

results <- list()
for (ds in names(datasets)) {
  df <- datasets[[ds]]
  inputs <- make_inputs(df, crs)
  params <- locoh_params(df)
  for (type in c("k", "r", "a")) {
    n <- unname(params[type])
    message("Running ", ds, ", type ", type, ", n = ", signif(n, 4))

    # --- 1. same results? --------------------------------------------------
    amt_hr <- amt::hr_locoh(inputs$trk, n = n, type = type, levels = levels)
    tt_hr <- hr_tt_locoh(
      inputs$tt,
      n = n,
      type = type,
      levels = levels,
      buffer = 1e-5
    )
    # amt returns the levels in the order given, hr_tt_locoh() from the
    # largest to the smallest
    amt_area <- as.numeric(amt_hr$locoh$area)
    tt_area <- rev(as.numeric(tt_hr$area))
    rel_diff <- max(abs(tt_area - amt_area) / amt_area)

    # --- 2. timings --------------------------------------------------------
    timing <- bench::mark(
      amt = amt::hr_locoh(inputs$trk, n = n, type = type, levels = levels),
      tidytracks_buffer = hr_tt_locoh(
        inputs$tt,
        n = n,
        type = type,
        levels = levels,
        buffer = 1e-5
      ),
      tidytracks = hr_tt_locoh(inputs$tt, n = n, type = type, levels = levels),
      check = FALSE,
      min_iterations = 3,
      max_iterations = 20,
      time_unit = "ms",
      memory = FALSE
    )
    med <- stats::setNames(
      as.numeric(timing$median),
      as.character(timing$expression)
    )
    results[[length(results) + 1]] <- data.frame(
      data = ds,
      locations = nrow(df),
      type = type,
      n = signif(n, 4),
      amt_ms = round(med[["amt"]], 1),
      tidytracks_buffer_ms = round(med[["tidytracks_buffer"]], 1),
      tidytracks_ms = round(med[["tidytracks"]], 1),
      speedup = round(med[["amt"]] / med[["tidytracks_buffer"]], 1),
      max_rel_area_diff = signif(rel_diff, 2)
    )
  }
}
results <- do.call(rbind, results)

# --- 3. where does the time go? ---------------------------------------------
# Time the C++ part (neighbours, hulls, sorting, levels) separately from the
# whole function, for the largest simulated data set.
df <- datasets[["sim_5000"]]
inputs <- make_inputs(df, crs)
xy <- as.matrix(df[, c("x", "y")])
breakdown <- bench::mark(
  cpp_only = tidytracks:::locoh_cpp(
    xy[, 1], xy[, 2],
    type = "k", n = 10, levels = levels, buffer = 0,
    shift_x = 0, shift_y = 0
  ),
  whole_function = hr_tt_locoh(inputs$tt, n = 10, type = "k", levels = levels),
  check = FALSE,
  min_iterations = 5,
  time_unit = "ms",
  memory = FALSE
)

print(sessionInfo())
cat("\n## Timings (median, in ms)\n\n")
print(results, row.names = FALSE)
cat("\n## Breakdown for sim_5000, type k (median, in ms)\n\n")
print(breakdown[, c("expression", "median")])
