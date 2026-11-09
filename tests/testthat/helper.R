# create a simple trajectory that goes out and comes back along the longitude
# axis
create_toy_df <- function() {
  set.seed(1)
  coords_df <- data.frame(
    longitude = c(
      0,
      1,
      2,
      3,
      4,
      5,
      6,
      5,
      4,
      3,
      2,
      1,
      0.5,
      -2,
      -3,
      -4,
      -5,
      -3 - 1.2,
      -0.3,
      -0.1,
      1,
      3,
      4,
      2.1,
      0.3,
      0.7,
      2.1,
      4,
      3,
      1.3
    ), # second individual
    latitude = rnorm(30, mean = 0, sd = 0.1) +
      c(
        rep(0, 6),
        rep(0.3, 5),
        rep(0.15, 7),
        rep(-0.3, 6),
        rep(0.1, 6)
      )
  )
  coords_df$date_time <- c(
    seq(
      from = as.POSIXct("2020-01-01 00:00:00"),
      by = "1 hour",
      length.out = 24
    ),
    seq(
      from = as.POSIXct("2020-02-10 00:00:00"),
      by = "1 hour",
      length.out = 6
    )
  )
  coords_df$bird_id <- paste0("id_", c(rep(1, 24), rep(2, 6)))
  coords_df$bird_id <- as.factor(coords_df$bird_id)
  return(coords_df)
}

# create this toy dataframe as a full move2 object with metadata
create_toy_tt <- function() {
  # make dataframe
  coords_df <- create_toy_df()
  # set up metadata for these events
  meta_df <- data.frame(
    bird_id = unique(coords_df$bird_id),
    species = c("species_a", "species_b")
  )
  meta_df$colony_sf <- sf_point_col(x = c(0, 0), y = c(0, 0), crs = 4326)

  # make tt (move2) object
  test_tt <- tt_read_data(
    events = coords_df,
    col_track_id = "bird_id",
    col_coords = c("longitude", "latitude"),
    col_date_time = "date_time",
    meta = meta_df
  )
  return(test_tt)
}

# A track that alternates fast straight commutes with slow, tortuous searches
# within patches of the given radius, in metres. Locations are regular in time.
simulate_ars_track <- function(id, patch_radius, n_patches = 6, seed = 1) {
  set.seed(seed)
  commute_step <- 3000
  search_step <- patch_radius / 8
  xy <- matrix(numeric(0), ncol = 2)
  centre <- c(500000, 5000000)
  for (patch in seq_len(n_patches)) {
    angle <- stats::runif(1, -pi / 4, pi / 4)
    commute <- seq(commute_step, 20 * patch_radius, by = commute_step)
    xy <- rbind(
      xy,
      cbind(centre[1] + commute * cos(angle), centre[2] + commute * sin(angle))
    )
    centre <- xy[nrow(xy), ]
    position <- centre
    for (step in seq_len(150)) {
      proposal <- position + stats::rnorm(2, 0, search_step)
      # stay within the patch
      if (sqrt(sum((proposal - centre)^2)) <= patch_radius) {
        position <- proposal
      }
      xy <- rbind(xy, position)
    }
    centre <- position
  }
  data.frame(
    id = id,
    x = xy[, 1],
    y = xy[, 2],
    time = as.POSIXct("2024-01-01", tz = "UTC") + 300 * seq_len(nrow(xy))
  )
}

as_ars_move2 <- function(df) {
  move2::mt_as_move2(
    df,
    coords = c("x", "y"),
    crs = 32631,
    time_column = "time",
    track_id_column = "id"
  )
}
