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

test_that("drop_duplicated_columns keeps the columns of each table apart", {
  # columns in both tables: sex with the same values, nest_lon with
  # different ones, and the time column of the events (set with move2, as
  # tidytracks keeps the columns apart)
  x <- move2::mt_as_event_attribute(example_tt, sex, nest_lon, .keep = TRUE)
  x$nest_lon <- 0
  meta <- show_meta(x)
  meta$date_time <- meta$nest_lat
  x <- move2::mt_set_track_data(x, meta)
  expect_warning(
    result <- drop_duplicated_columns(x),
    "'date_time', 'nest_lon' are both in the events and in the metadata"
  )
  # sex is kept in the metadata only
  expect_false("sex" %in% names(result))
  expect_equal(show_meta(result)$sex, show_meta(x)$sex)
  # the others are kept in both, renamed in the metadata
  expect_equal(result$nest_lon, x$nest_lon)
  expect_equal(result$date_time, x$date_time)
  expect_equal(
    names(show_meta(result)),
    c("track_id", "sex", "nest_lon.meta", "nest_lat", "date_time.meta")
  )
  # a column that the events are grouped by is kept in the events only
  x <- move2::mt_as_event_attribute(example_tt, sex, .keep = TRUE)
  x <- dplyr::group_by(x, sex)
  expect_no_message(result <- drop_duplicated_columns(x))
  expect_equal(dplyr::group_vars(result), "sex")
  expect_equal(result$sex, x$sex)
  expect_false("sex" %in% names(show_meta(result)))
  # without columns in both tables, nothing changes
  expect_equal(drop_duplicated_columns(example_tt), example_tt)
})

test_that("show_meta<- keeps the track id as the only column in both tables", {
  # a column of the new metadata with the same values as in the events is
  # removed from the events
  test_tt <- as_event_column(example_tt, sex)
  meta <- show_meta(test_tt)
  meta$sex <- show_meta(example_tt)$sex
  show_meta(test_tt) <- meta
  expect_false("sex" %in% names(test_tt))
  expect_equal(show_meta(test_tt)$sex, show_meta(example_tt)$sex)
  expect_equal(nrow(test_tt), nrow(example_tt))
  # with different values, the version in the metadata is renamed
  test_tt <- as_event_column(example_tt, sex)
  expect_warning(
    show_meta(test_tt)$sex <- "unknown",
    "the version(s) in the metadata are renamed 'sex.meta'",
    fixed = TRUE
  )
  expect_equal(test_tt$sex, as_event_column(example_tt, sex)$sex)
  expect_equal(show_meta(test_tt)$sex.meta, rep("unknown", 3))
  # if the events are grouped by it, it is removed from the metadata
  test_tt <- group_by_meta(example_tt, sex)
  show_meta(test_tt)$sex <- show_meta(example_tt)$sex
  expect_equal(dplyr::group_vars(test_tt), "sex")
  expect_true("sex" %in% names(test_tt))
  expect_false("sex" %in% names(show_meta(test_tt)))
})
