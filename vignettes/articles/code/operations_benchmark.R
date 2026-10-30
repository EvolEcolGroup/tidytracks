# Benchmark of common track operations in tidytracks (step distances, the
# McConnell speed filter and the splitting of tracks into trips) against
# move2, amt, trip and track2KBA, on tracks of a central place forager
# (simulated by operations_benchmark_tracks.R, in the same directory as this
# script, and stored in
# vignettes/articles/data/operations_benchmark_tracks.rds). The results are
# shown in the article "Benchmark of common track operations"
# (benchmark.Rmd, in the parent directory of this script), which also shows
# the code of the chunks of this script (the sections that start with a
# "## ---- label" line, read with knitr::read_chunk()).
#
# Run from the directory of the article (vignettes/articles), with tidytracks
# installed with R CMD INSTALL (rather than loaded with devtools::load_all(),
# which compiles its C++ code without optimisation), and move2, amt, trip,
# track2KBA, sp, sf and units available:
#
#   cd vignettes/articles
#   Rscript code/operations_benchmark.R
#
# Run it on an otherwise idle machine, with at least 96 GB of memory (it uses
# up to about 70 GB): it takes about two and a quarter hours (on an Intel
# i9-13900), and saves its results in data/operations_benchmark_*.csv, which
# the article reads. On a CPU with performance and efficiency cores (such as
# the i9-13900), run it on a single performance core, so that all the
# operations are timed on cores of the same speed (on Linux, `lscpu -e` lists
# the cores with their maximum frequency, and taskset runs R on the given
# core):
#
#   taskset -c 4 Rscript code/operations_benchmark.R
#
# `Rscript code/operations_benchmark.R quick` runs everything on the first
# locations of a few tracks, to check the script, and saves its results in a
# temporary directory.

## ---- script-setup ----
start_time <- Sys.time()
quick <- identical(commandArgs(trailingOnly = TRUE), "quick")
out_dir <- if (quick) tempdir() else "data"

## ---- packages ----
library(tidytracks)
# move2, amt, trip and track2KBA are not attached: their functions are called
# with ::, to make clear which package each of them comes from

## ---- read-tracks ----
# the tracks simulated by operations_benchmark_tracks.R: a list of four data
# frames (medium, long, season and year) with the id, longitude, latitude and
# time of each location, whether it is an outlier, and the location of the nest
# of each animal, ordered by track and time
datasets <- readRDS("data/operations_benchmark_tracks.rds")

## ---- quick-tracks ----
if (quick) {
  # the first locations of the first tracks of each data set
  first_locations <- function(df, tracks, locations) {
    df <- df[df$id %in% unique(df$id)[seq_len(tracks)], ]
    df[stats::ave(seq_len(nrow(df)), df$id, FUN = seq_along) <= locations, ]
  }
  datasets$medium <- first_locations(datasets$medium, 3, 200)
  datasets$long <- first_locations(datasets$long, 2, 1000)
  datasets$season <- first_locations(datasets$season, 2, 2000)
  datasets$year <- first_locations(datasets$year, 1, 5000)
}

## ---- copies ----
# The operations are timed on copies of the simulated tracks: the medium and
# long tracks from a single copy (the simulated tracks themselves) to 300
# copies (30,000 tracks of 1,000 locations, or 3,000 tracks of 10,000
# locations, i.e. 30 million locations), to see how their times grow with the
# size of the data, and enough copies of the tracks of a season and of a year
# for 30 million locations too (1,000 tracks of 30,000 locations, or 300
# tracks of 100,000 locations), to compare the packages on large data sets of
# long tracks
copies <- list(
  medium = c(1, 3, 10, 30, 100, 300),
  long = c(1, 3, 10, 30, 100, 300),
  season = 500,
  year = 300
)

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
  copies <- list(medium = c(1, 2), long = c(1, 2), season = 2, year = 2)
}

## ---- inputs ----
# the input of each package, built from a data frame of locations; tidytracks
# works on move2 objects, so the same object is used for both packages
make_inputs <- function(df) {
  move <- move2::mt_as_move2(
    df,
    coords = c("lon", "lat"),
    crs = 4326,
    time_column = "time",
    track_id_column = "id",
    track_attributes = c("nest_lon", "nest_lat")
  )
  # the nests, as a column of points in the metadata
  show_meta(move) <- show_meta(move) |>
    # nolint next: object_usage_linter.
    dplyr::mutate(nest = sf_point_col(nest_lon, nest_lat, crs = 4326))
  # trip objects are SpatialPointsDataFrames (from sp)
  trip_df <- df[, c("lon", "lat", "time", "id")]
  sp::coordinates(trip_df) <- c("lon", "lat")
  sp::proj4string(trip_df) <- sp::CRS("EPSG:4326")
  # the first location of each track, for its nest
  first <- !duplicated(df$id)
  list(
    tidytracks = move,
    move2 = move,
    # nolint next: object_usage_linter.
    amt = amt::make_track(df, lon, lat, time, id = id, crs = 4326),
    # the tracks are ordered by time, without duplicates, so trip() does not
    # need to correct them (which takes longer than its speed filter)
    trip = trip::trip(trip_df, c("time", "id"), correct_all = FALSE),
    track2KBA = list(
      data = data.frame(
        ID = df$id,
        Latitude = df$lat,
        Longitude = df$lon,
        DateTime = df$time
      ),
      colony = data.frame(
        ID = df$id[first],
        Latitude = df$nest_lat[first],
        Longitude = df$nest_lon[first]
      )
    )
  )
}

## ---- operations ----
# The operations timed, with the function of each package, which takes the
# input of its package (all the tracks)
operations <- list(
  # the distance from each location to the next one of the same track (in
  # km); amt measures the steps of a single track, so it is applied to each
  # track in turn, after nesting the tracks as shown in its documentation
  distance = list(
    tidytracks = function(input) {
      event_distance(input, units = as_units("km"))
    },
    move2 = function(input) {
      move2::mt_distance(input, units = "km")
    },
    amt = function(input) {
      input |>
        tidyr::nest(data = -id) |>
        dplyr::mutate(
          steps = purrr::map(data, amt::step_lengths, lonlat = TRUE)
        )
    },
    trip = function(input) {
      trip::trackDistance(input, prev = TRUE)
    }
  ),
  # the McConnell speed filter, with a maximum speed of 120 km/h
  speed_filter = list(
    tidytracks = function(input) {
      event_flag_mcconnell(input, max_speed = as_units(120, "km/h"))
    },
    trip = function(input) {
      trip::speedfilter(input, max.speed = 120)
    }
  ),
  # trips beyond 5 km of the nest, keeping the locations at the nest
  trip_split = list(
    tidytracks = function(input) {
      tt_split_trips(
        input,
        centre_col = "nest",
        buffer_outbound = as_units(5, "km"),
        buffer_inbound = as_units(5, "km"),
        complete = FALSE
      )
    },
    track2KBA = function(input) {
      track2KBA::tripSplit(
        input$data,
        colony = input$colony,
        innerBuff = 5,
        returnBuff = 5,
        duration = 0,
        nests = TRUE,
        rmNonTrip = FALSE,
        verbose = FALSE
      )
    }
  )
)

## ---- checks ----
# Compare the results of each package with those of tidytracks, for the
# data frame of locations `df`, which is ordered by track and time. Returns a
# data frame of checks: the largest relative difference between the step
# distances, the number of locations flagged differently by the speed
# filter, and the number of trips found by each package and of locations in
# them (and why they differ).
compare_distance <- function(results, df) {
  # in km, with NA for the last location of each track
  tidytracks <- as.numeric(results$tidytracks)
  last <- is.na(tidytracks)
  others <- list(
    move2 = as.numeric(results$move2),
    # amt::make_track() orders the locations by time, whatever their track,
    # so its tracks are nested in the order in which they start
    amt = unlist(
      results$amt$steps[match(unique(df$id), results$amt$id)]
    ) / 1000,
    trip = results$trip
  )
  data.frame(
    package = names(others),
    check = "largest relative difference in step distance",
    value = vapply(others, function(d) {
      stopifnot(length(d) == length(tidytracks))
      max(abs(d[!last] / tidytracks[!last] - 1), na.rm = TRUE)
    }, numeric(1))
  )
}
compare_speed_filter <- function(results, df) {
  flagged <- !results$tidytracks
  differ <- results$tidytracks != results$trip
  tracks_differ <- unique(df$id[differ])
  # the first two and last two locations of each track, which the filter
  # cannot flag
  n <- nrow(df)
  first <- c(TRUE, df$id[-1] != df$id[-n])
  last <- c(df$id[-1] != df$id[-n], TRUE)
  second <- c(FALSE, first[-n])
  second_to_last <- c(last[-1], FALSE)
  ends <- first | second | second_to_last | last
  # the tracks whose second-to-last location is an outlier
  outlier_second_to_last <- unique(df$id[second_to_last & df$outlier])
  data.frame(
    package = c(
      "both", "both", "tidytracks", "tidytracks", "trip", "trip", "trip"
    ),
    check = c(
      "outliers",
      "outliers among the first two or last two locations of a track",
      "locations flagged",
      "outliers flagged",
      "locations flagged differently",
      "tracks with locations flagged differently",
      "tracks with an outlier second to last, flagged differently"
    ),
    value = c(
      sum(df$outlier),
      sum(df$outlier & ends),
      sum(flagged),
      sum(flagged & df$outlier),
      sum(differ),
      length(tracks_differ),
      length(intersect(tracks_differ, outlier_second_to_last))
    )
  )
}
compare_trip_split <- function(results, df) {
  # tidytracks: the locations at the nest are in the dummy trips *_trip_na
  tt_trip <- results$tidytracks$trip_id
  tt_in_trip <- !grepl("_trip_na$", tt_trip)
  # track2KBA: the locations at the nest are in the trip "-1" (its results
  # are ordered by track and time, as df)
  stopifnot(identical(as.character(results$track2KBA$ID), df$id))
  kba_trip <- results$track2KBA$tripID
  kba_in_trip <- kba_trip != "-1"
  # track2KBA also includes in each trip the first location back within the
  # buffer, i.e. the location after the last one of a trip of tidytracks
  n <- nrow(df)
  after_trip <- c(FALSE, tt_in_trip[-n] & df$id[-1] == df$id[-n])
  return_to_nest <- !tt_in_trip & kba_in_trip & after_trip
  # tidytracks starts a trip at the last location of a track if it is the
  # first one beyond the buffer, but track2KBA does not
  last <- c(df$id[-1] != df$id[-n], TRUE)
  trip_at_end <- tt_in_trip & !kba_in_trip & last & !after_trip
  data.frame(
    package = c(
      "tidytracks", "track2KBA", "tidytracks", "track2KBA", "track2KBA",
      "tidytracks", "both"
    ),
    check = c(
      "trips", "trips", "locations in trips", "locations in trips",
      "returns to the nest in a trip",
      "trips of the last location of a track",
      "other locations in a trip in only one package"
    ),
    value = c(
      length(unique(tt_trip[tt_in_trip])),
      length(unique(kba_trip[kba_in_trip])),
      sum(tt_in_trip),
      sum(kba_in_trip),
      sum(return_to_nest),
      sum(trip_at_end),
      sum(tt_in_trip != kba_in_trip & !return_to_nest & !trip_at_end)
    )
  )
}
checks <- list(
  distance = compare_distance,
  speed_filter = compare_speed_filter,
  trip_split = compare_trip_split
)

## ---- timing ----
# Time an operation, once (system.time() first frees the memory used by the
# previous operations), and return its result and its time (in s)
time_operation <- function(operation, input) {
  seconds <- system.time(result <- operation(input))[["elapsed"]]
  list(result = result, seconds = seconds)
}

## ---- run-benchmark ----
# the data sets (the number of copies of each set of simulated tracks), from
# the smallest to the largest, so that no data set is timed just after a much
# larger one
runs <- data.frame(
  dataset = rep(names(copies), lengths(copies)),
  copies = unlist(copies, use.names = FALSE)
)
n_locations <- runs$copies * vapply(datasets[runs$dataset], nrow, numeric(1))
runs <- runs[order(n_locations), ]
timings <- list()
check_results <- list()
for (i in seq_len(nrow(runs))) {
  dataset <- runs$dataset[i]
  n_copies <- runs$copies[i]
  df <- recycle_tracks(datasets[[dataset]], n_copies)
  inputs <- make_inputs(df)
  n_tracks <- length(unique(df$id))
  for (operation in names(operations)) {
    results <- list()
    for (package in names(operations[[operation]])) {
      # track2KBA is only run on up to a million locations: its time grows
      # with the number of locations times the number of tracks, and it
      # would take hours on 10 million
      if (package == "track2KBA" && nrow(df) > 1e6) {
        next
      }
      message(
        "Timing ", operation, " with ", package, " on ", n_copies,
        " copies of the ", dataset, " tracks"
      )
      timed <- time_operation(
        operations[[operation]][[package]],
        inputs[[package]]
      )
      timings[[length(timings) + 1]] <- data.frame(
        dataset = dataset,
        copies = n_copies,
        tracks = n_tracks,
        locations = nrow(df) %/% n_tracks,
        operation = operation,
        package = package,
        seconds = timed$seconds
      )
      # the results are compared on the simulated tracks (their copies give
      # the same results)
      if (n_copies == 1) {
        results[[package]] <- timed$result
      }
      rm(timed)
    }
    if (n_copies == 1) {
      check_results[[length(check_results) + 1]] <- data.frame(
        dataset = dataset,
        operation = operation,
        checks[[operation]](results, df)
      )
    }
    rm(results)
  }
  rm(df, inputs)
}
timings <- do.call(rbind, timings)
check_results <- do.call(rbind, check_results)

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
  "tidytracks", "move2", "amt", "trip", "track2KBA", "sf", "sp", "s2",
  "geodist", "units"
)
session <- data.frame(
  item = c(
    "date", "R", "platform", "CPU", "cores", "cores used", "memory (GB)",
    "BLAS", session_packages
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
    )
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
write.csv(
  timings,
  file.path(out_dir, "operations_benchmark_timings.csv"),
  row.names = FALSE
)
write.csv(
  check_results,
  file.path(out_dir, "operations_benchmark_checks.csv"),
  row.names = FALSE
)
write.csv(
  session,
  file.path(out_dir, "operations_benchmark_session.csv"),
  row.names = FALSE
)
print(timings)
print(check_results)
message(
  "Results saved in ", out_dir, ", after ", round(run_minutes, 1), " minutes"
)
