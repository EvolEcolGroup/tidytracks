# Helper with distinct colony coordinates per bird (for geometry-filter test)
create_toy_tt_geo <- function() {
  coords_df <- create_toy_df() # nolint: object_usage_linter.
  meta_df <- data.frame(
    bird_id = unique(coords_df$bird_id),
    species = c("species_a", "species_b"),
    geometry = sf::st_sfc(
      sf::st_point(c(0, 10)), # id_1: colony latitude 10
      sf::st_point(c(0, 50)), # id_2: colony latitude 50
      crs = 4326
    )
  )
  colnames(meta_df)[which(colnames(meta_df) == "geometry")] <- "colony_sf"
  sf::st_geometry(meta_df) <- "colony_sf"
  tt_read_data(
    events = coords_df,
    col_track_id = "bird_id",
    col_coords = c("longitude", "latitude"),
    col_date_time = "date_time",
    meta = meta_df
  )
}

test_that("filter_by_meta works when metadata has a geometry column", {
  toy_tt <- create_toy_tt()
  result <- filter_by_meta(toy_tt, species == "species_a")

  expect_s3_class(result, "move2")
  # Only the one track for species_a (id_1) should remain
  expect_equal(nrow(show_meta(result)), 1L)
  # id_1 has 24 events in create_toy_df()
  expect_equal(nrow(result), 24L)
  expect_equal(show_meta(result)$species, "species_a")
})

test_that("filter_by_meta can filter on the metadata geometry column", {
  toy_tt <- create_toy_tt_geo()
  # id_1 colony at latitude 10, id_2 at latitude 50 — keep only latitude < 30
  result <- filter_by_meta(
    toy_tt,
    sf::st_coordinates(colony_sf)[, "Y"] < 30
  )

  expect_s3_class(result, "move2")
  expect_equal(nrow(show_meta(result)), 1L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")
})
