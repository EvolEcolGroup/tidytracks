test_that("as_meta_column works correctly", {
  # create a move2 object with sex in events table
  example_tt2 <- as_event_column(example_tt, sex)
  expect_false("sex" %in% colnames(show_meta(example_tt2)))
  expect_true("sex" %in% colnames(example_tt2))
  # now move it back to metadata
  example_tt3 <- as_meta_column(example_tt2, sex)
  expect_true("sex" %in% colnames(show_meta(example_tt3)))
  expect_false("sex" %in% colnames(example_tt3))

  # now use the .keep option, which is deprecated
  lifecycle::expect_deprecated(
    example_tt4 <- as_meta_column(example_tt2, sex, .keep = TRUE)
  )
  expect_true("sex" %in% colnames(show_meta(example_tt4)))
  expect_true("sex" %in% colnames(example_tt4))
})

test_that("as_meta_column does not duplicate a column in the metadata", {
  # sex is in both tables, with the same values (copied with move2)
  both_tt <- move2::mt_as_event_attribute(example_tt, sex, .keep = TRUE)
  result <- as_meta_column(both_tt, sex)
  expect_false("sex" %in% names(result))
  expect_equal(show_meta(result), show_meta(both_tt))
  # with .keep, nothing changes
  lifecycle::expect_deprecated(
    expect_equal(as_meta_column(both_tt, sex, .keep = TRUE), both_tt)
  )
  # with different values, an error
  both_tt$sex <- "unknown"
  expect_error(
    as_meta_column(both_tt, sex),
    "'sex' are both in the events and in the metadata, with values that differ"
  )
})
