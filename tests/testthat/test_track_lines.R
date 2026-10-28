test_that("track_lines returns the tracks in the order of the metadata", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # after ordering, the events are in the order a, b, c, whilst the metadata
  # is still in the order b, a, c
  example_tt_2 <- tt_order_time(example_tt_2)
  lines <- track_lines(example_tt_2)
  expect_equal(as.character(lines$track_id), c("b", "a", "c"))
  # each line joins the events of its track
  expect_equal(
    unname(sf::st_coordinates(lines[2, ])[, c("X", "Y")]),
    unname(sf::st_coordinates(
      example_tt_2[event_track_id(example_tt_2) == "a", ]
    ))
  )
})

test_that("track_lines works with sf metadata", {
  # an sf table of metadata, set without show_meta<- (which would turn it
  # into a plain table)
  meta_sf <- sf::st_as_sf(
    show_meta(example_tt),
    coords = c("nest_lon", "nest_lat"),
    crs = 4326,
    remove = FALSE
  )
  test_tt <- move2::mt_set_track_data(example_tt, meta_sf)
  # its geometry has the name of the geometry of the events, so it is renamed
  expect_message(
    lines <- track_lines(test_tt),
    "so it has been renamed 'geometry.meta'"
  )
  # the lines are those of the tracks, with their metadata
  expect_equal(
    sf::st_geometry(lines),
    sf::st_geometry(track_lines(example_tt))
  )
  expect_true(inherits(lines$geometry.meta, "sfc"))
})
