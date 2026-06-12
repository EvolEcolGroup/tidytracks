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