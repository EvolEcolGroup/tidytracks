# Benchmark of common tracking operations in tidytracks (step distances, the
# McConnell speed filter and the splitting of tracks into trips) against
# move2, amt, trip and track2KBA, on simulated tracks of a central place
# forager. The results are shown in the article "Performance of common
# tracking operations" (benchmark.Rmd, in the parent directory of this
# script), which also shows the code of the chunks of this script (the
# sections that start with a "## ---- label" line, read with
# knitr::read_chunk()).
#
# Run from the directory of the article (vignettes/articles), with tidytracks
# installed with R CMD INSTALL (rather than loaded with devtools::load_all(),
# which compiles its C++ code without optimisation), and move2, amt, trip,
# track2KBA, sp, sf, units and bench available:
#
#   cd vignettes/articles
#   Rscript code/operations_benchmark.R
#
# Run it on an otherwise idle machine: it takes about 20 minutes (on an Intel
# i7-10510U), and saves its results in benchmark-results.rds, which the
# article reads. `Rscript code/operations_benchmark.R quick` runs everything
# on a few small data sets, to check the script, and saves its results in a
# temporary directory.

## ---- script-setup ----
start_time <- Sys.time()
quick <- identical(commandArgs(trailingOnly = TRUE), "quick")
out_file <- if (quick) {
  file.path(tempdir(), "benchmark-results.rds")
} else {
  "benchmark-results.rds"
}

## ---- packages ----
library(tidytracks)
# move2, amt, trip and track2KBA are not attached: their functions are called
# with ::, to make clear which package each of them comes from

## ---- simulate-tracks ----
# Simulate the GPS tracks of a central place forager (e.g. a seabird breeding
# in a colony), with a location every 5 minutes: each animal alternates stays
# at its nest (of 2 to 12 hours) and foraging trips (of 6 to 24 hours, to a
# distance of 10 to 80 km from the nest, out on one bearing and back on
# another). The locations have a GPS error of about 30 m, and about 1 in 1000
# of them is an outlier, 50 to 300 km away from where the animal was.
# Returns a data frame with the id, longitude, latitude and time of each
# location, whether it is an outlier, and the location of the nest of each
# animal.
simulate_tracks <- function(n_tracks, n_locations, seed) {
  set.seed(seed)
  # the colony, and the nest of each animal, within about 100 m of it
  colony_lon <- -2.56
  colony_lat <- 56.19
  km_per_degree_lat <- 111.32
  km_per_degree_lon <- km_per_degree_lat * cos(colony_lat * pi / 180)
  ids <- sprintf(paste0("bird_%0", nchar(n_tracks), "d"), seq_len(n_tracks))
  nest_lon <- colony_lon + stats::rnorm(n_tracks, 0, 0.1) / km_per_degree_lon
  nest_lat <- colony_lat + stats::rnorm(n_tracks, 0, 0.1) / km_per_degree_lat
  one_track <- function(i) {
    # bouts at the nest and trips, alternating, until the track has
    # n_locations (each pair of bouts has at least 96 locations)
    n_pairs <- ceiling(n_locations / 96) + 1
    bout_length <- as.vector(rbind(
      sample(24:144, n_pairs, replace = TRUE),
      sample(72:288, n_pairs, replace = TRUE)
    ))
    on_trip <- rep(c(FALSE, TRUE), n_pairs)
    # the track starts at a random point of the first stay at the nest
    bout_length[1] <- sample(bout_length[1], 1)
    n_bouts <- which(cumsum(bout_length) >= n_locations)[1]
    bout_length <- bout_length[seq_len(n_bouts)]
    bout <- rep(seq_len(n_bouts), bout_length)[seq_len(n_locations)]
    # how far each location is through its bout (between 0 and 1)
    progress <- sequence(bout_length)[seq_len(n_locations)] /
      (bout_length[bout] + 1)
    # distance (in km) and bearing from the nest
    max_distance <- stats::runif(n_bouts, 10, 80)[bout]
    distance <- ifelse(on_trip[bout], max_distance * sin(pi * progress), 0)
    bearing <- stats::runif(n_bouts, 0, 2 * pi)[bout] +
      0.6 * sin(2 * pi * progress)
    # positions (in km from the nest), with the GPS error
    x <- distance * sin(bearing) + stats::rnorm(n_locations, 0, 0.03)
    y <- distance * cos(bearing) + stats::rnorm(n_locations, 0, 0.03)
    # outliers
    outlier <- which(stats::runif(n_locations) < 0.001)
    jump <- stats::runif(length(outlier), 50, 300)
    jump_bearing <- stats::runif(length(outlier), 0, 2 * pi)
    x[outlier] <- x[outlier] + jump * sin(jump_bearing)
    y[outlier] <- y[outlier] + jump * cos(jump_bearing)
    # a location every 5 minutes (give or take a few seconds), from a random
    # time on the first day of tracking
    time <- stats::runif(1, 0, 86400) +
      cumsum(c(0, 300 + sample(-5:5, n_locations - 1, replace = TRUE)))
    list(
      lon = nest_lon[i] + x / km_per_degree_lon,
      lat = nest_lat[i] + y / km_per_degree_lat,
      time = time,
      outlier = seq_len(n_locations) %in% outlier
    )
  }
  tracks <- lapply(seq_len(n_tracks), one_track)
  data.frame(
    id = rep(ids, each = n_locations),
    lon = unlist(lapply(tracks, `[[`, "lon")),
    lat = unlist(lapply(tracks, `[[`, "lat")),
    time = as.POSIXct("2024-06-01", tz = "UTC") +
      round(unlist(lapply(tracks, `[[`, "time"))),
    outlier = unlist(lapply(tracks, `[[`, "outlier")),
    nest_lon = rep(nest_lon, each = n_locations),
    nest_lat = rep(nest_lat, each = n_locations)
  )
}

## ---- data-sets ----
# Two series of data sets, to separate the cost of each location from the
# cost of each track: 10 tracks of increasing length, and 100,000 locations
# in all, split into an increasing number of tracks (10 tracks of 10,000
# locations are in both series)
series_tracks <- 10
track_lengths <- c(1000, 10000, 100000)
series_total <- 1e5
track_counts <- c(1, 10, 100, 1000)

## ---- quick-data-sets ----
if (quick) {
  series_tracks <- 2
  track_lengths <- c(100, 1000)
  series_total <- 1000
  track_counts <- c(1, 2, 10)
}

## ---- data-sets-table ----
data_sets <- unique(rbind(
  data.frame(tracks = series_tracks, locations = track_lengths),
  data.frame(tracks = track_counts, locations = series_total / track_counts)
))

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
    trip = trip::trip(trip_df, c("time", "id")),
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
# Time an operation: a first run (as a warm-up, which also gives its result),
# then, if it took less than a minute, more runs, until they have taken a
# minute (but at least 3 and at most 10 runs), whose median time is reported.
time_operation <- function(operation, input) {
  # free the memory used by the previous operations
  gc()
  start <- bench::hires_time()
  result <- operation(input)
  seconds <- as.numeric(bench::hires_time() - start)
  runs <- 1
  if (seconds < 60) {
    timing <- bench::mark(
      operation(input),
      min_time = 60,
      min_iterations = 3,
      max_iterations = 10,
      check = FALSE,
      memory = FALSE,
      filter_gc = FALSE
    )
    seconds <- as.numeric(timing$median)
    runs <- timing$n_itr
  }
  list(result = result, seconds = seconds, runs = runs)
}

## ---- run-benchmark ----
timings <- list()
check_results <- list()
for (i in seq_len(nrow(data_sets))) {
  n_tracks <- data_sets$tracks[i]
  n_locations <- data_sets$locations[i]
  df <- simulate_tracks(n_tracks, n_locations, seed = i)
  inputs <- make_inputs(df)
  for (operation in names(operations)) {
    results <- list()
    for (package in names(operations[[operation]])) {
      # track2KBA is not run on the largest data set (the 10 longest tracks):
      # its time grows faster than the length of the tracks, and it would
      # take more than 5 minutes (see its time on a single long track)
      if (package == "track2KBA" && n_tracks * n_locations > series_total) {
        next
      }
      message(
        "Timing ", operation, " with ", package, " on ", n_tracks,
        " tracks of ", n_locations, " locations"
      )
      timed <- time_operation(
        operations[[operation]][[package]],
        inputs[[package]]
      )
      results[[package]] <- timed$result
      timings[[length(timings) + 1]] <- data.frame(
        tracks = n_tracks,
        locations = n_locations,
        operation = operation,
        package = package,
        seconds = timed$seconds,
        runs = timed$runs
      )
    }
    # compare the results, if all the packages were run
    if (all(names(operations[[operation]]) %in% names(results))) {
      check_results[[length(check_results) + 1]] <- data.frame(
        tracks = n_tracks,
        locations = n_locations,
        operation = operation,
        checks[[operation]](results, df)
      )
    }
  }
}
timings <- do.call(rbind, timings)
check_results <- do.call(rbind, check_results)

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
session_packages <- c(
  "tidytracks", "move2", "amt", "trip", "track2KBA", "sf", "sp", "s2",
  "geodist", "units", "bench"
)
session <- data.frame(
  item = c("date", "R", "platform", "CPU", "cores", "BLAS", session_packages),
  value = c(
    format(Sys.Date()),
    R.version.string,
    R.version$platform,
    cpu,
    parallel::detectCores(),
    basename(sessionInfo()$BLAS),
    vapply(
      session_packages,
      function(p) as.character(utils::packageVersion(p)),
      character(1)
    )
  )
)

## ---- save ----
run_minutes <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))
saveRDS(
  list(
    timings = timings,
    checks = check_results,
    # the two series of data sets
    series = list(tracks = series_tracks, total = series_total),
    session = session,
    run_minutes = run_minutes
  ),
  out_file
)
print(timings)
print(check_results)
message(
  "Results saved in ", out_file, ", after ", round(run_minutes, 1), " minutes"
)
