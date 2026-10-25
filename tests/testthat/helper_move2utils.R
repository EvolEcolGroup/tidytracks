# create tracks with a few large spikes, so that the distribution of the
# speeds of the steps has a break between plausible steps and outliers
create_spiky_tracks <- function(n = 300, n_spikes = 2, seed = 1) {
  set.seed(seed)
  make_track <- function(id) {
    x <- cumsum(stats::rnorm(n, 0, 50))
    y <- cumsum(stats::rnorm(n, 0, 50))
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
