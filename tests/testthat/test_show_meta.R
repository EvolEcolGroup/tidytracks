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
