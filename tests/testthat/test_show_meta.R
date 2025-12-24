test_that("show_meta works correctly", {
  meta <- show_meta(shags_tt)
  expect_true(is.data.frame(meta))
  expect_equal(nrow(meta), mt_n_tracks(shags_tt))

  # Test setting metadata
  show_meta(shags_tt)$test_column <- "test_info"
  updated_meta <- show_meta(shags_tt)
  expect_true("test_column" %in% colnames(updated_meta))
  expect_equal(updated_meta$test_column[1], "test_info")
})