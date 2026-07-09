test_that("print function works correctly", {
  # Capture the output of the print function
  output <- capture.output(print(example_tt))

  # Check that the output contains expected strings
  testthat::expect_true(any(grepl("move2", output)))
  testthat::expect_true(any(grepl("show_meta", output)))
  testthat::expect_true(any(grepl("Simple feature", output)))

  # TODO: Add more specific tests changing the number of lines with n
})
