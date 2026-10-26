# Benchmark of home ranges of many tracks computed in parallel (one track per
# task) with futures, for hr_tt_mcp(), hr_tt_kde() and hr_tt_locoh().
#
# The parallel version is a prototype (parallel_prototype.patch), in which the
# loop over the tracks uses doFuture's %dofuture% instead of %do%, so that it
# follows the plan set with future::plan(). To run the benchmark, from the
# root of the package:
#
#   # 1. the current code, run sequentially
#   Rscript bench/parallel_benchmark.R current
#   # 2. the prototype, in a copy of the package, installed in its own library
#   git apply bench/parallel_prototype.patch
#   R CMD INSTALL -l <proto_lib> .
#   R_LIBS=<proto_lib> Rscript bench/parallel_benchmark.R futures
#
# Each run prints its timings (in seconds) and saves them, with the results of
# each method, to bench/parallel_<label>.rds, so that the runs can be
# compared.

args <- commandArgs(trailingOnly = TRUE)
label <- if (length(args) > 0) args[1] else "current"

suppressMessages(library(tidytracks))

# time an expression, in s
time_s <- function(expr) {
  start <- bench::hires_time()
  force(expr)
  as.numeric(bench::hires_time() - start)
}

# Simulate a track that stays within a home range (as in locoh_benchmark.R)
simulate_track <- function(n_locations) {
  xy <- matrix(0, n_locations, 2)
  centres <- rbind(c(0, 0), c(3000, 1500))
  centre <- 1
  for (i in 2:n_locations) {
    if (stats::runif(1) < 0.01) {
      centre <- 3 - centre
    }
    pull <- 0.05 * (centres[centre, ] - xy[i - 1, ])
    xy[i, ] <- xy[i - 1, ] + pull + stats::rnorm(2, sd = 100)
  }
  data.frame(
    x = xy[, 1] + 500000,
    y = xy[, 2] + 4000000,
    time = as.POSIXct("2024-01-01", tz = "UTC") + seq_len(n_locations) * 3600
  )
}

make_tracks <- function(n_tracks, n_locations) {
  set.seed(n_tracks * 1000 + n_locations)
  df <- do.call(rbind, lapply(seq_len(n_tracks), function(i) {
    track <- simulate_track(n_locations)
    track$id <- sprintf("t%04d", i)
    track
  }))
  move2::mt_as_move2(
    sf::st_as_sf(df, coords = c("x", "y"), crs = 27573),
    time_column = "time",
    track_id_column = "id"
  )
}

# number of tracks and of locations per track
scenarios <- list(c(4, 5000), c(20, 1000), c(200, 50), c(1000, 50))
methods <- list(
  mcp = function(tracks) hr_tt_mcp(tracks),
  kde_iso = function(tracks) hr_tt_kde(tracks, levels = c(0.5, 0.95)),
  kde_ud = function(tracks) hr_tt_kde(tracks),
  locoh = function(tracks) hr_tt_locoh(tracks, n = 10)
)
plans <- if (label == "current") {
  list(current = function() NULL)
} else {
  list(
    futures_sequential = function() future::plan("sequential"),
    multisession_2 = function() future::plan("multisession", workers = 2),
    multisession_4 = function() future::plan("multisession", workers = 4),
    multicore_4 = function() future::plan("multicore", workers = 4)
  )
}

data <- lapply(scenarios, function(s) make_tracks(s[1], s[2]))
timings <- list()
results <- list()
for (plan_name in names(plans)) {
  plans[[plan_name]]()
  # warm up the workers: they load the packages the first time they are used
  for (m in names(methods)) {
    invisible(methods[[m]](data[[1]]))
  }
  for (s in seq_along(scenarios)) {
    for (m in names(methods)) {
      # 1000 full UDs (rasters) are not worth the wait
      if (m == "kde_ud" && scenarios[[s]][1] > 200) {
        next
      }
      result <- NULL
      first <- time_s(result <- methods[[m]](data[[s]]))
      # slow cases are timed once, others take the median of 3 runs
      seconds <- if (first > 5) {
        first
      } else {
        stats::median(sapply(1:3, function(i) time_s(methods[[m]](data[[s]]))))
      }
      if (m == "kde_ud") {
        # compare the values of the rasters, not the pointers to them
        result$ud <- lapply(result$ud, terra::values)
      }
      key <- paste(scenarios[[s]][1], scenarios[[s]][2], m)
      if (is.null(results[[key]])) {
        results[[key]] <- result
      }
      timings[[length(timings) + 1]] <- data.frame(
        build = label,
        plan = plan_name,
        tracks = scenarios[[s]][1],
        locations = scenarios[[s]][2],
        method = m,
        seconds = round(seconds, 3),
        same_as_first_plan = isTRUE(all.equal(results[[key]], result))
      )
    }
  }
  if (label != "current") {
    future::plan("sequential")
  }
}
timings <- do.call(rbind, timings)
print(timings, row.names = FALSE)
saveRDS(
  list(timings = timings, results = results),
  file.path("bench", paste0("parallel_", label, ".rds"))
)
