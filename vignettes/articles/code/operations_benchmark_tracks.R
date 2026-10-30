# Simulation of the tracks used to benchmark common track operations of
# tidytracks against move2, amt, trip and track2KBA (with
# operations_benchmark.R). The benchmark is shown in the article "Benchmark of
# common track operations" (benchmark.Rmd, in the parent directory of this
# script), which also shows the code of the chunks of this script (the
# sections that start with a "## ---- label" line, read with
# knitr::read_chunk()).
#
# The tracks are stored in
# vignettes/articles/data/operations_benchmark_tracks.rds, so the benchmark
# can be run without simulating them again. To simulate them, run from the
# directory of the article (vignettes/articles):
#
#   cd vignettes/articles
#   Rscript code/operations_benchmark_tracks.R
#
# It takes a few seconds, and replaces data/operations_benchmark_tracks.rds
# (each data set has its own seed, so the same version of R gives the same
# tracks). `Rscript code/operations_benchmark_tracks.R quick` simulates tiny
# data sets, to check the script, and saves them in a temporary file.

## ---- tracks-setup ----
quick <- identical(commandArgs(trailingOnly = TRUE), "quick")
tracks_file <- if (quick) {
  tempfile(fileext = ".rds")
} else {
  "data/operations_benchmark_tracks.rds"
}

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
simulate_tracks <- function(name, n_tracks, n_locations, seed) {
  set.seed(seed)
  # the colony, and the nest of each animal, within about 100 m of it
  colony_lon <- -2.56
  colony_lat <- 56.19
  km_per_degree_lat <- 111.32
  km_per_degree_lon <- km_per_degree_lat * cos(colony_lat * pi / 180)
  ids <- sprintf("%s_%03d", name, seq_len(n_tracks))
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

## ---- simulate-datasets ----
# the number of tracks and of locations per track of each data set: the
# medium and long tracks have the same number of locations in all, and a few
# tracks of a season and of a year are enough for large data sets of their
# copies
sizes <- list(
  medium = c(tracks = 100, locations = 1000),
  long = c(tracks = 10, locations = 10000),
  season = c(tracks = 2, locations = 30000),
  year = c(tracks = 1, locations = 100000)
)

## ---- run-simulations ----
if (quick) {
  sizes <- list(
    medium = c(tracks = 3, locations = 200),
    long = c(tracks = 2, locations = 1000),
    season = c(tracks = 2, locations = 2000),
    year = c(tracks = 1, locations = 5000)
  )
}
datasets <- lapply(names(sizes), function(name) {
  simulate_tracks(
    name,
    n_tracks = sizes[[name]][["tracks"]],
    n_locations = sizes[[name]][["locations"]],
    seed = match(name, names(sizes))
  )
})
names(datasets) <- names(sizes)
saveRDS(datasets, tracks_file, compress = "xz")
message("Tracks saved in ", tracks_file)
