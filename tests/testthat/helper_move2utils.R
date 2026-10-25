# test data shared by the tests of the move2utils wrappers. move2utils looks
# for breaks in the distribution of the speeds of the steps, and needs at
# least 10 steps with a positive speed, so example_tt (15 events in 3 tracks)
# is too small for most of its functions

# create tracks with a few large spikes, so that the distribution of the
# speeds of the steps has a break between plausible steps and outliers
create_spiky_tracks <- function(n = 300, n_spikes = 2, seed = 1) {
  # fixed seed, as the suggestions of move2utils are sensitive to the data
  set.seed(seed)
  make_track <- function(id) {
    # a random walk with steps of about 50 m every 10 minutes
    x <- cumsum(stats::rnorm(n, 0, 50))
    y <- cumsum(stats::rnorm(n, 0, 50))
    # spikes are single events displaced by 20 km, never the first or last
    # event, so that each spike gives two fast steps (out and back)
    spikes <- sample(2:(n - 1), n_spikes)
    x[spikes] <- x[spikes] + 20000
    data.frame(
      id = id,
      x = x,
      y = y,
      time = as.POSIXct("2024-01-01", tz = "UTC") + (seq_len(n) - 1) * 600
    )
  }
  df <- rbind(make_track("a"), make_track("b"))
  move2::mt_as_move2(
    sf::st_as_sf(df, coords = c("x", "y"), crs = 32630),
    time_column = "time",
    track_id_column = "id"
  )
}

# create two random-walk tracks with irregular time intervals (track b is
# stored first in the metadata)
create_irregular_tracks <- function(n = 200, seed = 2) {
  set.seed(seed)
  make_track <- function(id) {
    data.frame(
      id = id,
      x = cumsum(stats::rnorm(n, 0, 100)),
      y = cumsum(stats::rnorm(n, 0, 100)),
      # intervals of at least a minute, about 11 minutes on average, so that
      # the times are strictly increasing within each track
      time = as.POSIXct("2024-01-01", tz = "UTC") +
        cumsum(round(stats::rexp(n, 1 / 600)) + 60)
    )
  }
  # track b comes first (in the events and in the metadata), so that results
  # in metadata order can be told apart from results sorted by track id
  df <- rbind(make_track("b"), make_track("a"))
  move2::mt_as_move2(
    sf::st_as_sf(df, coords = c("x", "y"), crs = 32630),
    time_column = "time",
    track_id_column = "id"
  )
}
