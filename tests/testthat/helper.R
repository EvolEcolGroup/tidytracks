# create a simple trajectory that goes out and comes back along the longitude
# axis
create_toy_df <- function() {
  set.seed(1)
  coords_df <- data.frame(
    longitude = c(
      0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0.5, -2, -3,
      -4, -5, -3 - 1.2, -0.3, -0.1, 1, 3, 4, 2.1,
      0.3, 0.7, 2.1, 4, 3, 1.3
    ), # second individual
    latitude = rnorm(30, mean = 0, sd = 0.1) +
      c(
        rep(0, 6), rep(0.3, 5), rep(0.15, 7), rep(-0.3, 6),
        rep(0.1, 6)
      )
  )
  coords_df$date_time <- c(
    seq(
      from = as.POSIXct("2020-01-01 00:00:00"),
      by = "1 hour", length.out = 24
    ),
    seq(
      from = as.POSIXct("2020-02-10 00:00:00"),
      by = "1 hour", length.out = 6
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
    species = c("species_a", "species_b"),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 0)),
      sf::st_point(c(0, 0)), crs = 4326)
  )
  colnames(meta_df)[which(colnames(meta_df) == "geometry")] <- "colony_sf"
  sf::st_geometry(meta_df) <- "colony_sf"
  # make tt (move2) object
  test_tt <- tt_read_data(events = coords_df,
                          col_track_id = "bird_id",
                          col_coords = c("longitude", "latitude"),
                          col_date_time = "date_time",
                          meta = meta_df
  )
  return(test_tt)
}