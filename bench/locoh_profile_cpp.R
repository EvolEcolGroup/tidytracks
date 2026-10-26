# Profile of the C++ code of hr_tt_locoh(), phase by phase, and of a parallel
# (OpenMP) prototype of the neighbour search and of the hulls.
#
# Run from the root of the package:
#   Rscript bench/locoh_profile_cpp.R

set.seed(42)

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
  cbind(xy[, 1] + 500000, xy[, 2] + 4000000)
}

# compile the harness, with the package's src/ on the include path
Sys.setenv(PKG_CPPFLAGS = paste0("-I", normalizePath("src")))
Rcpp::sourceCpp("bench/locoh_profile_cpp.cpp")

phases <- list()
parallel <- list()
for (n_locations in c(5000, 50000, 200000)) {
  xy <- simulate_track(n_locations)
  d10 <- FNN::get.knn(xy, k = 10)$nn.dist[, 10]
  params <- c(k = 10, r = stats::median(d10), a = 10 * stats::median(d10))
  for (type in names(params)) {
    p <- apply(
      sapply(1:5, function(i) {
        locoh_phases(xy[, 1], xy[, 2], type, params[[type]], 0.95)
      }),
      1,
      stats::median
    )
    phases[[length(phases) + 1]] <- data.frame(
      locations = n_locations,
      type = type,
      t(round(p, 1))
    )
  }
  for (threads in c(1, 2, 4)) {
    parallel[[length(parallel) + 1]] <- data.frame(
      locations = n_locations,
      threads = threads,
      knn_and_hulls_ms = round(stats::median(sapply(1:5, function(i) {
        locoh_knn_hulls_parallel(xy[, 1], xy[, 2], 10L, threads)
      })), 1)
    )
  }
}
cat("## Phases of the C++ code (median, in ms)\n\n")
print(do.call(rbind, phases), row.names = FALSE)
cat("\n## Neighbours (k, n = 10) and hulls with OpenMP (median, in ms)\n\n")
print(do.call(rbind, parallel), row.names = FALSE)
