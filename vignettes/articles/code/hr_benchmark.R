# Benchmark of the home range estimators of tidytracks (MCP, KDE and LoCoH)
# against those of amt and adehabitatHR, on tracks simulated with amt (by
# hr_benchmark_tracks.R, in the same directory as this script, and stored in
# vignettes/articles/data/hr_benchmark_tracks.rds). The results are shown in
# the article "Benchmark of home range estimators" (hr_benchmark.Rmd, in the
# parent directory of this script), which also shows the code of the chunks
# of this script (the sections that start with a "## ---- label" line, read
# with knitr::read_chunk()).
#
# Run from the directory of the article (vignettes/articles), with tidytracks
# installed with R CMD INSTALL (devtools::load_all() compiles the C++ code of
# hr_tt_locoh() without optimisation), and amt, adehabitatHR and sp
# available, with a larger protection stack than the default (which
# adehabitatHR exceeds when it builds the polygons of LoCoH on thousands of
# locations):
#
#   cd vignettes/articles
#   Rscript --max-ppsize=500000 code/hr_benchmark.R
#
# Run it on an otherwise idle machine: it takes about 25 minutes (on an Intel
# i9-13900), and saves its results in data/hr_benchmark_*.csv, which the
# article reads. On a CPU with performance and efficiency cores (such as the
# i9-13900), run it on a single performance core, so that all the estimators
# are timed on cores of the same speed (on Linux, `lscpu -e` lists the cores
# with their maximum frequency, and taskset runs R on the given core):
#
#   taskset -c 4 Rscript --max-ppsize=500000 code/hr_benchmark.R
#
# `Rscript code/hr_benchmark.R quick` runs everything on the first locations
# of a few tracks, to check the script, and saves its results in a temporary
# directory.

## ---- script-setup ----
start_time <- Sys.time()
quick <- identical(commandArgs(trailingOnly = TRUE), "quick")
out_dir <- if (quick) tempdir() else "data"

## ---- packages ----
library(tidytracks)
# amt and adehabitatHR are not attached: their functions are called with ::,
# to make clear which package each of them comes from

## ---- read-tracks ----
# the tracks simulated by hr_benchmark_tracks.R: a list of two data frames
# (medium and long) with the id, coordinates (x and y, in EPSG:32630) and time
# of each location
datasets <- readRDS("data/hr_benchmark_tracks.rds")

## ---- quick-tracks ----
if (quick) {
  # the first locations of the first tracks of each data set
  first_locations <- function(df, tracks, locations) {
    df <- df[df$id %in% unique(df$id)[seq_len(tracks)], ]
    df[stats::ave(seq_len(nrow(df)), df$id, FUN = seq_along) <= locations, ]
  }
  datasets$medium <- first_locations(datasets$medium, 3, 50)
  datasets$long <- first_locations(datasets$long, 2, 300)
}

## ---- copies ----
# The home ranges are estimated on the simulated tracks, and on 10 copies of
# them (1,000 tracks of 500 locations, or 100 tracks of 10,000 locations)
copies <- c(1, 10)

# copies of the tracks of a data frame ordered by track and time, each with
# its own id (that of the track, after the number of the copy), so that the
# copies are also ordered by track and time
recycle_tracks <- function(df, n_copies) {
  if (n_copies == 1) {
    return(df)
  }
  copy <- rep(seq_len(n_copies), each = nrow(df))
  out <- df[rep(seq_len(nrow(df)), n_copies), ]
  out$id <- paste0(
    "copy", sprintf(paste0("%0", nchar(n_copies), "d"), copy), "_", out$id
  )
  rownames(out) <- NULL
  out
}

## ---- quick-copies ----
if (quick) {
  copies <- c(1, 2)
}

## ---- inputs ----
# the input of each package, built from a data frame of locations
make_inputs <- function(df) {
  list(
    tidytracks = mt_as_move2(
      sf::st_as_sf(df, coords = c("x", "y"), crs = 32630),
      time_column = "time",
      track_id_column = "id"
    ),
    # nolint next: object_usage_linter.
    amt = amt::make_track(df, x, y, time, id = id, crs = 32630),
    adehabitatHR = sp::SpatialPointsDataFrame(
      df[, c("x", "y")],
      data = data.frame(id = factor(df$id)),
      proj4string = sp::CRS("EPSG:32630")
    )
  )
}

## ---- grid ----
# the grid on which the KDEs of all the tracks are estimated: the extent of
# all the locations, extended on each side by half its longest side, with 200
# cells along its longest side. It is given to each package in its own way:
# a bounding box and a resolution for tidytracks, a raster for amt, and the
# centres of its cells for adehabitatHR.
make_grid <- function(df) {
  side <- max(diff(range(df$x)), diff(range(df$y)))
  raster <- terra::rast(
    xmin = min(df$x) - side / 2,
    xmax = max(df$x) + side / 2,
    ymin = min(df$y) - side / 2,
    ymax = max(df$y) + side / 2,
    resolution = side / 100,
    crs = "EPSG:32630"
  )
  centres <- terra::xyFromCell(raster, seq_len(terra::ncell(raster)))
  list(
    bbox = c(
      xmin = terra::xmin(raster),
      ymin = terra::ymin(raster),
      xmax = terra::xmax(raster),
      ymax = terra::ymax(raster)
    ),
    res = terra::res(raster)[1],
    raster = raster,
    pixels = sp::SpatialPixels(
      sp::SpatialPoints(centres, proj4string = sp::CRS("EPSG:32630"))
    )
  )
}

## ---- estimators ----
iso_levels <- c(0.5, 0.95)

# The home range of each track, with each method and estimator, from the
# input of its package (all the tracks) and the grid for the KDE. Each
# estimator is named after its package (its first word), followed, for the
# KDE of tidytracks, by its method. amt estimates the home range of a single
# track, so it is applied to each track in turn.
estimators <- list(
  mcp = list(
    tidytracks = function(input, grid) {
      hr_tt_mcp(input, levels = iso_levels)
    },
    amt = function(input, grid) {
      input |>
        tidyr::nest(data = -id) |>
        dplyr::mutate(hr = purrr::map(data, amt::hr_mcp, levels = iso_levels))
    },
    # adehabitatHR estimates a single level at a time
    adehabitatHR = function(input, grid) {
      lapply(iso_levels, function(level) {
        adehabitatHR::mcp(input, percent = 100 * level, unout = "m2")
      })
    }
  ),
  # the UDs, with the reference bandwidth of each track, and tidytracks with
  # both of its methods: binned (its default, which bins the locations onto
  # the grid before smoothing them, as amt does) and exact (which evaluates
  # the kernel of every location at every cell, as adehabitatHR does)
  kde_ud = list(
    "tidytracks (binned)" = function(input, grid) {
      hr_tt_kde(
        input,
        h = "h_ref_indiv",
        bbox = grid$bbox,
        res = grid$res,
        method = "binned"
      )
    },
    "tidytracks (exact)" = function(input, grid) {
      hr_tt_kde(
        input,
        h = "h_ref_indiv",
        bbox = grid$bbox,
        res = grid$res,
        method = "exact"
      )
    },
    amt = function(input, grid) {
      input |>
        tidyr::nest(data = -id) |>
        dplyr::mutate(hr = purrr::map(data, amt::hr_kde, trast = grid$raster))
    },
    adehabitatHR = function(input, grid) {
      adehabitatHR::kernelUD(input, h = "href", grid = grid$pixels)
    }
  ),
  # the isopleths, starting from the locations (i.e. including the UDs)
  kde_iso = list(
    "tidytracks (binned)" = function(input, grid) {
      hr_tt_kde(
        input,
        h = "h_ref_indiv",
        bbox = grid$bbox,
        res = grid$res,
        levels = iso_levels,
        method = "binned"
      )
    },
    "tidytracks (exact)" = function(input, grid) {
      hr_tt_kde(
        input,
        h = "h_ref_indiv",
        bbox = grid$bbox,
        res = grid$res,
        levels = iso_levels,
        method = "exact"
      )
    },
    amt = function(input, grid) {
      input |>
        tidyr::nest(data = -id) |>
        dplyr::mutate(hr = purrr::map(data, function(track) {
          ud <- amt::hr_kde(track, trast = grid$raster, levels = iso_levels)
          amt::hr_isopleths(ud)
        }))
    },
    adehabitatHR = function(input, grid) {
      ud <- adehabitatHR::kernelUD(input, h = "href", grid = grid$pixels)
      lapply(iso_levels, function(level) {
        adehabitatHR::getverticeshr(ud, percent = 100 * level, unout = "m2")
      })
    }
  ),
  # hulls of each location and its 10 nearest neighbours
  locoh = list(
    tidytracks = function(input, grid) {
      hr_tt_locoh(input, n = 10, type = "k", levels = iso_levels)
    },
    amt = function(input, grid) {
      input |>
        tidyr::nest(data = -id) |>
        dplyr::mutate(
          hr = purrr::map(data, amt::hr_locoh, n = 10, levels = iso_levels)
        )
    },
    # adehabitatHR counts the location itself in k, so k = 11 gives the
    # same hulls; it returns the union of the hulls at every step, from which
    # the isopleths are picked (see areas below)
    adehabitatHR = function(input, grid) {
      adehabitatHR::LoCoH.k(input, k = 11, unout = "m2")
    }
  )
)

## ---- areas ----
# The areas of the home ranges (in m^2) from the results of each method and
# package, as a data frame with one row per track and level, to check that
# the packages give the same home ranges.
area_table <- function(id, level, area) {
  data.frame(id = as.character(id), level = level, area = as.numeric(area))
}
# amt gives one element of a list-column per track
amt_areas <- function(result, get_hr) {
  do.call(rbind, Map(function(id, hr) {
    hr <- get_hr(hr)
    area_table(id, hr$level, hr$area)
  }, result$id, result$hr))
}
# adehabitatHR gives one SpatialPolygonsDataFrame per level
adehabitat_areas <- function(result) {
  do.call(rbind, Map(function(level, hr) {
    area_table(hr$id, level, hr$area)
  }, iso_levels, result))
}
areas <- list(
  mcp = list(
    tidytracks = function(result) {
      area_table(result$id, result$level, result$area)
    },
    amt = function(result) amt_areas(result, function(hr) hr$mcp),
    adehabitatHR = adehabitat_areas
  ),
  kde_iso = list(
    tidytracks = function(result) {
      area_table(result$id, result$level, result$area)
    },
    amt = function(result) amt_areas(result, function(hr) hr),
    adehabitatHR = adehabitat_areas
  ),
  locoh = list(
    tidytracks = function(result) {
      area_table(result$id, result$level, result$area)
    },
    # amt reports the coverage reached rather than the level requested
    amt = function(result) {
      amt_areas(result, function(hr) {
        data.frame(
          level = iso_levels,
          area = hr$locoh$area[order(hr$locoh$level)]
        )
      })
    },
    # as amt and tidytracks, the isopleth for each level is the union of
    # hulls whose coverage (in %) is closest to the level
    adehabitatHR = function(result) {
      do.call(rbind, Map(function(id, hr) {
        rows <- vapply(iso_levels, function(level) {
          which.min(abs(hr$percent - 100 * level))
        }, integer(1))
        area_table(id, iso_levels, hr$area[rows])
      }, names(result), result))
    }
  )
)

## ---- timing ----
# Time an estimator, once (system.time() first frees the memory used by the
# previous estimators), and return its result and its time (in s)
time_estimator <- function(estimator, input, grid) {
  seconds <- system.time(result <- estimator(input, grid))[["elapsed"]]
  list(result = result, seconds = seconds)
}

## ---- run-benchmark ----
timings <- list()
area_results <- list()
# from the smallest data sets to the largest, so that no data set is timed
# just after a much larger one
for (n_copies in copies) {
  for (dataset in names(datasets)) {
    df <- recycle_tracks(datasets[[dataset]], n_copies)
    inputs <- make_inputs(df)
    grid <- make_grid(df)
    n_tracks <- length(unique(df$id))
    for (method in names(estimators)) {
      for (estimator in names(estimators[[method]])) {
        # the package of the estimator, i.e. the first word of its name (e.g.
        # tidytracks for "tidytracks (exact)"), which gives its input and how
        # to extract its areas
        package <- sub(" .*", "", estimator)
        # LoCoH in adehabitatHR is only run on the medium tracks, as it would
        # take most of an hour on their copies, and hours on the long tracks
        # (see the scaling below)
        too_long <- dataset == "long" || n_copies > 1
        if (method == "locoh" && package == "adehabitatHR" && too_long) {
          next
        }
        message(
          "Timing ", method, ", ", estimator, " on ", n_copies,
          " copies of the ", dataset, " tracks"
        )
        timed <- time_estimator(
          estimators[[method]][[estimator]],
          inputs[[package]],
          grid
        )
        timings[[length(timings) + 1]] <- data.frame(
          dataset = dataset,
          copies = n_copies,
          tracks = n_tracks,
          locations = nrow(df) %/% n_tracks,
          method = method,
          package = package,
          estimator = estimator,
          seconds = timed$seconds
        )
        # the areas are compared on the simulated tracks (their copies give
        # the same home ranges)
        if (n_copies == 1 && method %in% names(areas)) {
          area_results[[length(area_results) + 1]] <- data.frame(
            dataset = dataset,
            method = method,
            package = package,
            estimator = estimator,
            areas[[method]][[package]](timed$result)
          )
        }
        rm(timed)
      }
    }
    rm(df, inputs, grid)
  }
}
timings <- do.call(rbind, timings)
area_results <- do.call(rbind, area_results)

## ---- locoh-scaling ----
# LoCoH on a single track, as the number of locations increases: the first
# 500 to 10,000 locations of the first long track (adehabitatHR only up to
# 2000 locations: on 5000 locations, it runs out of protection stack, after
# several minutes, even with the largest one that R allows)
track <- datasets$long[datasets$long$id == unique(datasets$long$id)[1], ]
n_locations <- c(500, 1000, 2000, 5000, 10000)
if (quick) {
  n_locations <- c(100, 200)
}
locoh_scaling <- list()
for (n in n_locations) {
  inputs <- make_inputs(track[seq_len(n), ])
  for (package in names(estimators$locoh)) {
    if (package == "adehabitatHR" && n > 2000) {
      next
    }
    message("Timing LoCoH on ", n, " locations, ", package)
    # the input of adehabitatHR for a single track has no id, so that it
    # returns a single home range
    input <- inputs[[package]]
    if (package == "adehabitatHR") {
      input <- sp::SpatialPoints(input)
    }
    timed <- time_estimator(estimators$locoh[[package]], input, NULL)
    locoh_scaling[[length(locoh_scaling) + 1]] <- data.frame(
      locations = n,
      package = package,
      seconds = timed$seconds
    )
  }
}
locoh_scaling <- do.call(rbind, locoh_scaling)

## ---- session ----
# the machine and the versions of the software used
# the value of a field of a file of /proc (on Linux), or NA
proc_field <- function(file, field) {
  tryCatch(
    sub(
      "^.*:\\s*", "",
      grep(paste0("^", field), readLines(file), value = TRUE)[1]
    ),
    error = function(e) NA_character_,
    warning = function(w) NA_character_
  )
}
memory_kb <- as.numeric(
  sub(" kB$", "", proc_field("/proc/meminfo", "MemTotal"))
)
blas <- sessionInfo()$BLAS
session_packages <- c(
  "tidytracks", "amt", "adehabitatHR", "sp", "sf", "terra", "MASS",
  "KernSmooth"
)
session <- data.frame(
  item = c(
    "date", "R", "platform", "CPU", "cores", "cores used", "memory (GB)",
    "BLAS", session_packages, "GEOS"
  ),
  value = c(
    format(Sys.Date()),
    R.version.string,
    R.version$platform,
    proc_field("/proc/cpuinfo", "model name"),
    parallel::detectCores(),
    # the cores on which R may run (e.g. a single core, with taskset)
    proc_field("/proc/self/status", "Cpus_allowed_list"),
    round(memory_kb / 2^20),
    # with its directory, which tells which BLAS it is on Debian and Ubuntu
    # (e.g. blas for the reference BLAS, and openblas-pthread for OpenBLAS)
    file.path(basename(dirname(blas)), basename(blas)),
    vapply(
      session_packages,
      function(p) as.character(utils::packageVersion(p)),
      character(1)
    ),
    sf::sf_extSoftVersion()[["GEOS"]]
  )
)

## ---- save ----
run_minutes <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
# the most memory used by R during the benchmark
peak_memory_kb <- as.numeric(
  sub(" kB$", "", proc_field("/proc/self/status", "VmHWM"))
)
session <- rbind(
  session,
  data.frame(
    item = c("run time (minutes)", "peak memory (GB)"),
    value = c(round(run_minutes), round(peak_memory_kb / 2^20))
  )
)
# system.time() measures times to the millisecond
timings$seconds <- round(timings$seconds, 3)
locoh_scaling$seconds <- round(locoh_scaling$seconds, 3)
write.csv(
  timings,
  file.path(out_dir, "hr_benchmark_timings.csv"),
  row.names = FALSE
)
area_results$area <- round(area_results$area, 1)
write.csv(
  area_results,
  file.path(out_dir, "hr_benchmark_areas.csv"),
  row.names = FALSE
)
write.csv(
  locoh_scaling,
  file.path(out_dir, "hr_benchmark_locoh_scaling.csv"),
  row.names = FALSE
)
write.csv(
  session,
  file.path(out_dir, "hr_benchmark_session.csv"),
  row.names = FALSE
)
print(timings)
print(locoh_scaling)
# the largest relative difference between the areas from each estimator and
# those from tidytracks (with its exact method, for the KDE), for each data
# set, method and level
is_reference <- area_results$estimator %in%
  c("tidytracks", "tidytracks (exact)")
compared <- merge(
  area_results[!is_reference, ],
  area_results[is_reference, c("dataset", "method", "id", "level", "area")],
  by = c("dataset", "method", "id", "level"),
  suffixes = c("", "_reference")
)
compared$rel_diff <- abs(compared$area / compared$area_reference - 1)
print(aggregate(
  rel_diff ~ dataset + method + estimator + level,
  data = compared,
  FUN = max
))
message(
  "Results saved in ", out_dir, ", after ", round(run_minutes, 1), " minutes"
)
