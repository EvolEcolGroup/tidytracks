# Benchmark of the home range estimators of tidytracks (MCP, KDE and LoCoH)
# against those of amt and adehabitatHR, on tracks simulated with amt (by
# hr_benchmark_tracks.R, in the same directory as this script, and stored in
# vignettes/articles/data/hr_benchmark_tracks.rds). The results are shown in
# the article "Benchmarking home ranges against amt and adehabitatHR"
# (hr_benchmark.Rmd, in the parent directory of this script), which also
# shows the code of the chunks of this script (the sections that
# start with a "## ---- label" line, read with knitr::read_chunk()).
#
# Run from the directory of the article (vignettes/articles), with tidytracks
# installed with R CMD INSTALL (devtools::load_all() compiles the C++ code of
# hr_tt_locoh() without optimisation), and amt, adehabitatHR, sp and bench
# available:
#
#   cd vignettes/articles
#   Rscript code/hr_packages_benchmark.R
#
# Run it on an otherwise idle machine: it takes about 35 minutes (on an Intel
# i7-10510U), and saves its results in data/hr_benchmark_*.csv, which the
# article reads. `Rscript code/hr_packages_benchmark.R quick` runs everything
# on the first locations of a few tracks, to check the script, and saves its
# results in a temporary directory.

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

# The home range of each track, with each method and package, from the input
# of the package (all the tracks) and the grid for the KDE. amt estimates the
# home range of a single track, so it is applied to each track in turn.
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
  # the UDs, with the reference bandwidth of each track
  kde_ud = list(
    tidytracks = function(input, grid) {
      hr_tt_kde(input, h = "h_ref_indiv", bbox = grid$bbox, res = grid$res)
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
    tidytracks = function(input, grid) {
      hr_tt_kde(
        input,
        h = "h_ref_indiv",
        bbox = grid$bbox,
        res = grid$res,
        levels = iso_levels
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
# Time an estimator: a first run, which also gives its results, then, if it
# took less than a minute, 5 more runs, whose median time is reported.
time_estimator <- function(estimator, input, grid) {
  start <- bench::hires_time()
  result <- estimator(input, grid)
  seconds <- as.numeric(bench::hires_time() - start)
  runs <- 1
  if (seconds < 60) {
    timing <- bench::mark(
      estimator(input, grid),
      iterations = 5,
      check = FALSE,
      memory = FALSE,
      filter_gc = FALSE
    )
    seconds <- as.numeric(timing$median)
    runs <- 5
  }
  list(result = result, seconds = seconds, runs = runs)
}

## ---- run-benchmark ----
timings <- list()
area_results <- list()
for (dataset in names(datasets)) {
  df <- datasets[[dataset]]
  inputs <- make_inputs(df)
  grid <- make_grid(df)
  n_tracks <- length(unique(df$id))
  for (method in names(estimators)) {
    for (package in names(estimators[[method]])) {
      # LoCoH in adehabitatHR would take hours on the long tracks (see the
      # scaling below)
      if (method == "locoh" && package == "adehabitatHR" && dataset == "long") {
        next
      }
      message("Timing ", dataset, ", ", method, ", ", package)
      timed <- time_estimator(
        estimators[[method]][[package]],
        inputs[[package]],
        grid
      )
      timings[[length(timings) + 1]] <- data.frame(
        dataset = dataset,
        tracks = n_tracks,
        locations = nrow(df) / n_tracks,
        method = method,
        package = package,
        seconds = timed$seconds,
        runs = timed$runs
      )
      if (method %in% names(areas)) {
        area_results[[length(area_results) + 1]] <- data.frame(
          dataset = dataset,
          method = method,
          package = package,
          areas[[method]][[package]](timed$result)
        )
      }
    }
  }
}
timings <- do.call(rbind, timings)
area_results <- do.call(rbind, area_results)

## ---- locoh-scaling ----
# LoCoH on a single track, as the number of locations increases: the first
# 500 to 10,000 locations of the first long track (adehabitatHR only up to
# 2000 locations, as it would take hours on the full track)
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
      seconds = timed$seconds,
      runs = timed$runs
    )
  }
}
locoh_scaling <- do.call(rbind, locoh_scaling)

## ---- session ----
# the machine and the versions of the software used
cpu <- tryCatch(
  sub(
    "^.*:\\s*", "",
    grep("^model name", readLines("/proc/cpuinfo"), value = TRUE)[1]
  ),
  error = function(e) NA_character_,
  warning = function(w) NA_character_
)
session <- data.frame(
  item = c(
    "date", "R", "platform", "CPU", "cores", "BLAS", "tidytracks", "amt",
    "adehabitatHR", "sf", "GEOS", "terra", "MASS", "KernSmooth"
  ),
  value = c(
    format(Sys.Date()),
    R.version.string,
    R.version$platform,
    cpu,
    parallel::detectCores(),
    basename(sessionInfo()$BLAS),
    as.character(utils::packageVersion("tidytracks")),
    as.character(utils::packageVersion("amt")),
    as.character(utils::packageVersion("adehabitatHR")),
    as.character(utils::packageVersion("sf")),
    sf::sf_extSoftVersion()[["GEOS"]],
    as.character(utils::packageVersion("terra")),
    as.character(utils::packageVersion("MASS")),
    as.character(utils::packageVersion("KernSmooth"))
  )
)

## ---- save ----
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
# the largest relative difference between the areas from each package and
# those from tidytracks, for each data set, method and level
reference <- area_results[area_results$package == "tidytracks", ]
compared <- merge(
  area_results[area_results$package != "tidytracks", ],
  reference[, c("dataset", "method", "id", "level", "area")],
  by = c("dataset", "method", "id", "level"),
  suffixes = c("", "_tidytracks")
)
compared$rel_diff <- abs(compared$area / compared$area_tidytracks - 1)
print(aggregate(
  rel_diff ~ dataset + method + package + level,
  data = compared,
  FUN = max
))
message(
  "Results saved in ", out_dir, ", after ",
  format(round(difftime(Sys.time(), start_time, units = "mins"), 1))
)
