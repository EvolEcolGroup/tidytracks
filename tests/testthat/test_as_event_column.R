test_that("as_event_column works correctly", {
  expect_false("sex" %in% colnames(example_tt))
  expect_true("sex" %in% colnames(show_meta(example_tt)))
  example_tt2 <- as_event_column(example_tt, sex)
  expect_true("sex" %in% colnames(example_tt2))
  expect_false("sex" %in% colnames(show_meta(example_tt2)))

  # now use the .keep option
  example_tt3 <- as_event_column(example_tt, sex, .keep = TRUE)
  expect_true("sex" %in% colnames(example_tt3))
  expect_true("sex" %in% colnames(show_meta(example_tt3)))
})

test_that("as_event_column works with sf metadata", {
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
    test_tt2 <- as_event_column(test_tt, sex, geometry.meta),
    "so it has been renamed 'geometry.meta'"
  )
  expect_equal(test_tt2$sex, as_event_column(example_tt, sex)$sex)
  expect_true(inherits(test_tt2$geometry.meta, "sfc"))
  # the events keep their own geometry
  expect_equal(sf::st_geometry(test_tt2), sf::st_geometry(example_tt))
})
