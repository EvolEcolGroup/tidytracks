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

test_that("filter_by_meta is not affected by columns named as its variables", {
  toy_tt <- create_toy_tt()
  # columns with the names of variables used internally by filter_by_meta
  toy_tt$ids <- "not an id"
  toy_tt$new_tracks <- "not an id"
  toy_tt$keep_events <- FALSE
  show_meta(toy_tt)$track_ids_to_keep <- "not an id"

  result <- filter_by_meta(toy_tt, species == "species_a")
  expect_equal(nrow(result), 24L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")

  result <- filter_by_meta(toy_tt, .track_id = "id_2")
  expect_equal(nrow(result), 6L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_2")
})

test_that("filter_by_meta works on grouped objects", {
  toy_tt <- dplyr::group_by(create_toy_tt(), bird_id)
  result <- filter_by_meta(toy_tt, species == "species_a")
  expect_equal(nrow(result), 24L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")
  expect_equal(dplyr::group_vars(result), "bird_id")
  expect_equal(dplyr::n_groups(result), 1L)

  result <- filter_by_meta(toy_tt, .track_id = "id_2")
  expect_equal(nrow(result), 6L)
  expect_equal(dplyr::n_groups(result), 1L)
})

test_that("filter_by_meta works when the metadata is an sf table", {
  # the geometry of the metadata has the name of the geometry of the events
  toy_tt <- create_toy_tt_sf_meta("geometry")
  result <- filter_by_meta(toy_tt, species == "species_b")
  expect_equal(nrow(result), 6L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_2")
  # filter on the geometry of the metadata (id_1 has its colony at latitude 10)
  result <- filter_by_meta(toy_tt, sf::st_coordinates(geometry)[, "Y"] < 30)
  expect_equal(nrow(result), 24L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")
  expect_s3_class(show_meta(result)$geometry, "sfc")
  # the events keep their own geometry
  expect_equal(
    sf::st_coordinates(result),
    sf::st_coordinates(toy_tt)[1:24, ]
  )

  # the geometry of the metadata has another name
  toy_tt <- create_toy_tt_sf_meta("colony_sf")
  result <- filter_by_meta(toy_tt, sf::st_coordinates(colony_sf)[, "Y"] > 30)
  expect_equal(nrow(result), 6L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_2")
  expect_equal(
    sf::st_coordinates(result),
    sf::st_coordinates(toy_tt)[25:30, ]
  )
})

test_that("filter_by_meta works with spatial predicates on sfc columns", {
  toy_tt <- create_toy_tt_geo()
  # a box around the colony of id_1 (latitude 10), but not that of id_2
  box <- sf::st_as_sfc(
    sf::st_bbox(c(xmin = -5, ymin = 5, xmax = 5, ymax = 15), crs = 4326)
  )
  result <- filter_by_meta(
    toy_tt,
    lengths(sf::st_intersects(colony_sf, box)) > 0
  )
  expect_equal(nrow(result), 24L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")
  # the sfc column of the metadata is kept, with its crs
  expect_s3_class(show_meta(result)$colony_sf, "sfc")
  expect_equal(sf::st_crs(show_meta(result)$colony_sf), sf::st_crs(4326))
})

test_that("filter_by_meta combines conditions with .track_id", {
  toy_tt <- create_toy_tt_geo()
  # both tracks meet the condition, and .track_id keeps one of them
  result <- filter_by_meta(
    toy_tt,
    sf::st_coordinates(colony_sf)[, "Y"] > 0,
    .track_id = "id_2"
  )
  expect_equal(nrow(result), 6L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_2")
  # the condition and .track_id keep different tracks
  result <- filter_by_meta(toy_tt, species == "species_a", .track_id = "id_2")
  expect_equal(nrow(result), 0L)
  expect_equal(nrow(show_meta(result)), 0L)
})

test_that("filter_by_meta returns no events if no track is kept", {
  result <- filter_by_meta(create_toy_tt_geo(), species == "species_c")
  expect_s3_class(result, "move2")
  expect_equal(nrow(result), 0L)
  expect_equal(nrow(show_meta(result)), 0L)
  expect_s3_class(show_meta(result)$colony_sf, "sfc")
})

test_that("filter_by_meta keeps the groups set by group_by_meta", {
  toy_tt <- group_by_meta(create_toy_tt_geo(), species)
  result <- filter_by_meta(toy_tt, sf::st_coordinates(colony_sf)[, "Y"] < 30)
  expect_equal(nrow(result), 24L)
  expect_equal(as.character(show_meta(result)$bird_id), "id_1")
  expect_equal(dplyr::group_vars(result), "species")
  expect_equal(dplyr::n_groups(result), 1L)
})
