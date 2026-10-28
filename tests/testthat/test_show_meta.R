test_that("show_meta works correctly", {
  toy_tt <- create_toy_tt()
  meta <- show_meta(toy_tt)
  expect_true(is.data.frame(meta))
  expect_equal(nrow(meta), mt_n_tracks(toy_tt))

  # Test setting metadata
  show_meta(toy_tt)$test_column <- "test_info"
  updated_meta <- show_meta(toy_tt)
  expect_true("test_column" %in% colnames(updated_meta))
  expect_equal(updated_meta$test_column[1], "test_info")
})

test_that("show_meta<- stores sf metadata as a plain table", {
  test_tt <- example_tt
  meta_sf <- sf::st_as_sf(
    show_meta(test_tt),
    coords = c("nest_lon", "nest_lat"),
    crs = 4326,
    remove = FALSE
  )
  # the geometry column of an sf table is called geometry by default, as is
  # the geometry column of the events
  expect_message(
    show_meta(test_tt) <- meta_sf,
    "so it has been renamed 'geometry.meta'"
  )
  expect_false(inherits(show_meta(test_tt), "sf"))
  expect_equal(show_meta(test_tt)$geometry.meta, sf::st_geometry(meta_sf))
  # so it can be joined to the events, which keep their own geometry
  joined <- as_event_column(test_tt, "geometry.meta")
  expect_equal(sf::st_geometry(joined), sf::st_geometry(example_tt))
  # a geometry column with another name is kept as it is
  sf::st_geometry(meta_sf) <- "nest"
  expect_no_message(show_meta(test_tt) <- meta_sf)
  expect_equal(show_meta(test_tt)$nest, sf::st_geometry(meta_sf))
})

test_that("show_meta<- rejects more than one row per track", {
  test_tt <- example_tt
  # e.g. from joining a table with more than one row for a track
  extra <- data.frame(track_id = c("a", "a", "b", "c"), colony = c(1, 2, 2, 3))
  expect_error(
    show_meta(test_tt) <- dplyr::left_join(
      show_meta(test_tt),
      extra,
      by = "track_id"
    ),
    "The metadata has more than one row for track(s) a",
    fixed = TRUE
  )
})
