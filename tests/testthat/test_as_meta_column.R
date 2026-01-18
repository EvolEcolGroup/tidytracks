test_that("as_meta_column works correctly", {
  # create a move2 object with sex in events table
  example_tt2 <- as_event_column(example_tt, sex)
  expect_false("sex" %in% colnames(show_meta(example_tt2)))
  expect_true("sex" %in% colnames(example_tt2))
  # now move it back to metadata
  example_tt3 <- as_meta_column(example_tt2, sex)
  expect_true("sex" %in% colnames(show_meta(example_tt3)))
  expect_false("sex" %in% colnames(example_tt3))

    # now use the .keep option
  example_tt4 <- as_meta_column(example_tt2, sex, .keep = TRUE)
  expect_true("sex" %in% colnames(show_meta(example_tt4)))
  expect_true("sex" %in% colnames(example_tt4))
})
