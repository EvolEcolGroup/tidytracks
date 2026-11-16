test_that("as_event_column works correctly", {
  expect_false("sex" %in% colnames(example_tt))
  expect_true("sex" %in% colnames(show_meta(example_tt)))
  example_tt2 <- as_event_column(example_tt, sex)
  expect_true("sex" %in% colnames(example_tt2))
  expect_false("sex" %in% colnames(show_meta(example_tt2)))

  # now use the .keep option, which is deprecated
  lifecycle::expect_deprecated(
    example_tt3 <- as_event_column(example_tt, sex, .keep = TRUE)
  )
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

test_that("as_event_column does not duplicate a column already in the events", {
  # sex is in both tables, with the same values (copied with move2)
  both_tt <- move2::mt_as_event_attribute(example_tt, sex, .keep = TRUE)
  result <- as_event_column(both_tt, sex)
  expect_equal(names(result), names(both_tt))
  expect_false("sex" %in% names(show_meta(result)))
  expect_equal(result$sex, both_tt$sex)
  # with .keep, nothing changes
  lifecycle::expect_deprecated(
    expect_equal(as_event_column(both_tt, sex, .keep = TRUE), both_tt)
  )
  # other columns are moved as usual
  result <- as_event_column(both_tt, sex, nest_lon)
  expect_setequal(names(result), c(names(both_tt), "nest_lon"))
  expect_equal(names(show_meta(result)), c("track_id", "nest_lat"))
  # with different values, an error
  both_tt$sex <- "unknown"
  expect_error(
    as_event_column(both_tt, sex),
    "'sex' are both in the events and in the metadata, with values that differ"
  )
})
