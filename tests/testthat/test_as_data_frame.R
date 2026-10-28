test_that("as.data.frame.move2 returns event attributes by default", {
  result <- as.data.frame(example_tt)

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), nrow(example_tt))
  expect_named(result, c("track_id", "date_time", "geometry"))
  expect_equal(result$track_id, example_tt$track_id)
  expect_equal(result$date_time, example_tt$date_time)
  expect_equal(result$geometry, example_tt$geometry)
  expect_false(any(names(show_meta(example_tt))[-1] %in% names(result)))
})

test_that("as.data.frame.move2 can include metadata attributes", {
  result <- as.data.frame(example_tt, include_meta = TRUE)
  metadata <- show_meta(example_tt)
  metadata_columns <- setdiff(names(metadata), "track_id")
  metadata_index <- match(result$track_id, metadata$track_id)

  expect_true(all(metadata_columns %in% names(result)))
  for (column in metadata_columns) {
    expect_equal(result[[column]], metadata[[column]][metadata_index])
  }
})

test_that("as.data.frame.move2 can include sf metadata", {
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
    result <- as.data.frame(test_tt, include_meta = TRUE),
    "so it has been renamed 'geometry.meta'"
  )
  expect_equal(
    result$sex,
    as.data.frame(example_tt, include_meta = TRUE)$sex
  )
  expect_true(inherits(result$geometry.meta, "sfc"))
  # the events keep their own geometry, also when it is replaced by the
  # coordinates
  expect_equal(result$geometry, sf::st_geometry(example_tt))
  expect_message(
    result_xy <- as.data.frame(
      test_tt,
      include_meta = TRUE,
      drop_geometry = TRUE
    ),
    "geometry.meta"
  )
  expect_equal(
    result_xy[c("X", "Y")],
    as.data.frame(example_tt, drop_geometry = TRUE)[c("X", "Y")]
  )
})

test_that("as.data.frame.move2 can replace geometry with coordinates", {
  result <- as.data.frame(
    example_tt,
    include_meta = TRUE,
    drop_geometry = TRUE
  )
  coordinates <- sf::st_coordinates(example_tt$geometry)
  expected_columns <- c("sex", "nest_lon", "nest_lat", "X", "Y")

  expect_equal(nrow(result), nrow(example_tt))
  expect_false("geometry" %in% names(result))
  expect_true(all(expected_columns %in% names(result)))
  expect_equal(result$X, coordinates[, "X"])
  expect_equal(result$Y, coordinates[, "Y"])
})

test_that("as.data.frame.move2 replaces geometry without metadata", {
  result <- as.data.frame(example_tt, drop_geometry = TRUE)
  coordinates <- sf::st_coordinates(example_tt)

  expect_s3_class(result, "data.frame")
  expect_named(result, c("track_id", "date_time", "X", "Y"))
  expect_equal(result$date_time, example_tt$date_time)
  expect_equal(result$X, coordinates[, "X"])
  expect_equal(result$Y, coordinates[, "Y"])
})
