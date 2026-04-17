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
