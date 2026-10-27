# Simulation, with amt, of the tracks used to benchmark the home range
# estimators of tidytracks against those of amt and adehabitatHR (with
# hr_packages_benchmark.R). The benchmark is shown in the article
# "Benchmarking home ranges against amt and adehabitatHR" (hr_benchmark.Rmd,
# in the parent directory of this script), which also shows the code of the
# chunks of this script (the sections that start with a "## ---- label" line,
# read with knitr::read_chunk()).
#
# The tracks are stored in vignettes/articles/data/hr_benchmark_tracks.rds,
# so the benchmark can be run without simulating them again. To simulate
# them, run from the directory of the article (vignettes/articles), with amt
# available:
#
#   cd vignettes/articles
#   Rscript code/hr_benchmark_tracks.R
#
# It takes about 8 minutes on 4 cores, and replaces
# data/hr_benchmark_tracks.rds (each track has its own seed, so the same
# versions of amt and R give the same tracks).
# `Rscript code/hr_benchmark_tracks.R quick` simulates tiny data sets, to
# check the script, and saves them in a temporary file.

## ---- tracks-setup ----
quick <- identical(commandArgs(trailingOnly = TRUE), "quick")
tracks_file <- if (quick) {
  tempfile(fileext = ".rds")
} else {
  "data/hr_benchmark_tracks.rds"
}

## ---- simulate-track ----
# amt simulates movement from a redistribution kernel, which needs a map of
# the landscape; this one is uniform, as the model below only depends on the
# position of the animal
landscape <- terra::rast(
  xmin = -20000, xmax = 20000, ymin = -20000, ymax = 20000,
  resolution = 100, crs = "EPSG:32630", vals = 0, names = "habitat"
)
# an integrated step selection model: step lengths with a gamma distribution
# (200 m per hour on average), turning angles with a von Mises distribution
# (some directional persistence), and selection against locations far from
# the centre of the home range, at (0, 0)
movement_model <- amt::make_issf_model(
  coefs = c("I(x2_^2 + y2_^2)" = -1e-6),
  sl = amt::make_gamma_distr(shape = 2, scale = 100),
  ta = amt::make_vonmises_distr(kappa = 1)
)

# simulate a track with one location per hour
simulate_track <- function(id, n_locations, seed) {
  set.seed(seed)
  start <- amt::make_start(
    c(0, 0),
    time = as.POSIXct("2024-01-01", tz = "UTC"),
    crs = 32630
  )
  kernel <- amt::redistribution_kernel(
    movement_model,
    start = start,
    map = landscape,
    # the model only uses the coordinates at the end of each step, so the
    # landscape does not need to be queried
    fun = function(xy, map) xy,
    # the number of candidate steps drawn at each step (the default, 1e6, is
    # much slower)
    n.control = 1e3
  )
  path <- amt::simulate_path(kernel, n.steps = n_locations - 1)
  data.frame(
    id = id,
    # moved to the centre of UTM zone 30N
    x = path$x_ + 500000,
    y = path$y_ + 4000000,
    time = path$t_
  )
}

## ---- simulate-datasets ----
# the number of tracks and of locations per track of each data set
sizes <- list(
  medium = c(tracks = 100, locations = 500),
  long = c(tracks = 10, locations = 10000)
)

# simulate the tracks of a data set in parallel (with forked processes, which
# are not available on Windows), each track with its own seed
simulate_dataset <- function(name) {
  size <- sizes[[name]]
  tracks <- parallel::mclapply(
    seq_len(size[["tracks"]]),
    function(i) {
      simulate_track(
        id = sprintf("%s_%03d", name, i),
        n_locations = size[["locations"]],
        seed = 1000 * match(name, names(sizes)) + i
      )
    },
    mc.cores = parallel::detectCores()
  )
  # a failed simulation returns an error instead of a data frame
  stopifnot(all(vapply(tracks, is.data.frame, logical(1))))
  do.call(rbind, tracks)
}

## ---- run-simulations ----
if (quick) {
  sizes <- list(
    medium = c(tracks = 3, locations = 50),
    long = c(tracks = 2, locations = 300)
  )
}
datasets <- lapply(names(sizes), simulate_dataset)
names(datasets) <- names(sizes)
saveRDS(datasets, tracks_file, compress = "xz")
message("Tracks saved in ", tracks_file)
