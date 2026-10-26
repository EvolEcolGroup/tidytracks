# Profile of hr_tt_locoh(): where does the time go?
#
# Run from the root of the package, with tidytracks installed (built with
# optimisation, e.g. with R CMD INSTALL, rather than devtools::load_all(),
# which compiles the C++ code without optimisation):
#   Rscript bench/locoh_profile.R
#
# 1. For single tracks of increasing length, time each stage of
#    hr_tt_locoh(): the C++ code (neighbours, hulls, sorting, levels), the
#    conversion of the hulls to an sfc, the unions computed by GEOS, and what
#    follows (casting, shifting back, areas).
# 2. For many short tracks, time the whole function, to see the cost per
#    track.

library(tidytracks)

set.seed(42)

# time an expression, in ms
time_ms <- function(expr) {
  start <- bench::hires_time()
  force(expr)
  as.numeric(bench::hires_time() - start) * 1000
}

# Simulate a track that stays within a home range (as in locoh_benchmark.R):
# a random walk pulled back towards one of two centres, in metres.
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
    time = as.POSIXct("2024-01-01", tz = "UTC") + seq_len(n_locations) * 3600,
    id = "sim"
  )
}

as_tracks <- function(df) {
  move2::mt_as_move2(
    sf::st_as_sf(df, coords = c("x", "y"), crs = 27573),
    time_column = "time",
    track_id_column = "id"
  )
}

# The stages of locoh_one_group(), timed one by one (projected data, no
# buffer)
stage_times <- function(xy, n, type, levels = c(0.5, 0.95)) {
  shift <- c(mean(range(xy[, 1])), mean(range(xy[, 2])))
  times <- c(cpp = 0, st_sfc = 0, union_batch = 0, union_merge = 0, post = 0)
  times[["cpp"]] <- time_ms(
    hulls <- tidytracks:::locoh_cpp(
      xy[, 1], xy[, 2], type, n, levels, 0, shift[1], shift[2]
    )
  )
  geometry <- vector("list", length(levels))
  union_so_far <- NULL
  so_far <- 0
  for (i in order(hulls$n_hulls)) {
    m <- hulls$n_hulls[i]
    if (m > so_far) {
      new <- seq(so_far + 1, m)
      new <- new[!hulls$degenerate[new]]
      times[["st_sfc"]] <- times[["st_sfc"]] +
        time_ms(sfc <- sf::st_sfc(hulls$hulls[new]))
      times[["union_batch"]] <- times[["union_batch"]] +
        time_ms(new_union <- sf::st_union(sfc))
      times[["union_merge"]] <- times[["union_merge"]] + time_ms(
        union_so_far <- if (is.null(union_so_far)) {
          new_union
        } else {
          sf::st_union(c(union_so_far, new_union))
        }
      )
      so_far <- m
    }
    geometry[[i]] <- union_so_far
  }
  times[["post"]] <- time_ms({
    geometry <- sf::st_cast(do.call(c, geometry), "MULTIPOLYGON") + shift
    sf::st_area(sf::st_set_crs(geometry, 27573))
  })
  times
}

# --- 1. stages, for single tracks --------------------------------------------
stages <- list()
for (n_locations in c(1000, 5000, 20000, 50000)) {
  df <- simulate_track(n_locations)
  xy <- as.matrix(df[, c("x", "y")])
  tracks <- as_tracks(df)
  d10 <- FNN::get.knn(xy, k = 10)$nn.dist[, 10]
  params <- c(k = 10, r = stats::median(d10), a = 10 * stats::median(d10))
  for (type in names(params)) {
    n <- params[[type]]
    # medians of 3 runs
    st <- apply(
      sapply(1:3, function(i) stage_times(xy, n, type)),
      1,
      stats::median
    )
    whole <- stats::median(sapply(1:3, function(i) {
      time_ms(hr_tt_locoh(tracks, n = n, type = type))
    }))
    stages[[length(stages) + 1]] <- data.frame(
      locations = n_locations,
      type = type,
      whole_ms = round(whole),
      cpp_ms = round(st[["cpp"]], 1),
      st_sfc_ms = round(st[["st_sfc"]], 1),
      union_ms = round(st[["union_batch"]] + st[["union_merge"]]),
      post_ms = round(st[["post"]], 1),
      cpp_share = paste0(round(100 * st[["cpp"]] / whole), "%"),
      union_share = paste0(
        round(100 * (st[["union_batch"]] + st[["union_merge"]]) / whole), "%"
      )
    )
  }
}
cat("## Stages, single tracks (median, in ms)\n\n")
print(do.call(rbind, stages), row.names = FALSE)

# --- 2. many short tracks ----------------------------------------------------
many <- list()
for (cfg in list(c(10, 500), c(100, 50), c(1000, 50))) {
  df <- do.call(rbind, lapply(seq_len(cfg[1]), function(i) {
    d <- simulate_track(cfg[2])
    d$id <- sprintf("t%04d", i)
    d
  }))
  tracks <- as_tracks(df)
  whole <- stats::median(sapply(1:3, function(i) {
    time_ms(hr_tt_locoh(tracks, n = 10))
  }))
  many[[length(many) + 1]] <- data.frame(
    tracks = cfg[1],
    locations_per_track = cfg[2],
    whole_ms = round(whole),
    per_track_ms = round(whole / cfg[1], 1)
  )
}
cat("\n## Many short tracks (median, in ms)\n\n")
print(do.call(rbind, many), row.names = FALSE)
