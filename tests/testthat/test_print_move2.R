# Tests for custom tidytracks printing
#
# These tests cover:
#   * immediate switching of the registered S3 method;
#   * reporting the method that is actually registered;
#   * sticky TRUE and FALSE preferences;
#   * non-sticky session-only overrides;
#   * restoration of the stored preference at package load;
#   * argument validation;
#   * the custom print implementation.
#
# Tests that write a persistent preference redirect the configuration helper to
# a temporary file, so local and CI runs never modify the developer's real
# tidytracks preference.
#
# S3 method registration is process-global, so each test that changes it
# restores the original move2 method afterwards.

restore_move2_printing <- function() {
  registerS3method(
    genname = "print",
    class = "move2",
    method = get(
      "print.move2",
      envir = asNamespace("move2"),
      inherits = FALSE
    ),
    envir = asNamespace("base")
  )
}


test_that("method registration switches in both directions", {
  on.exit(restore_move2_printing(), add = TRUE)

  original <- get(
    "print.move2",
    envir = asNamespace("move2"),
    inherits = FALSE
  )
  custom <- get(
    "print_move2_tt",
    envir = asNamespace("tidytracks"),
    inherits = FALSE
  )

  tidytracks:::.set_tidytracks_printing(TRUE)
  expect_identical(utils::getS3method("print", "move2"), custom)

  tidytracks:::.set_tidytracks_printing(FALSE)
  expect_identical(utils::getS3method("print", "move2"), original)
})


test_that("tidytracks_print reports the method actually registered", {
  on.exit(restore_move2_printing(), add = TRUE)

  tidytracks:::.set_tidytracks_printing(TRUE)
  expect_true(tidytracks::tidytracks_printing())

  tidytracks:::.set_tidytracks_printing(FALSE)
  expect_false(tidytracks::tidytracks_printing())
})


test_that("settings are sticky by default", {
  on.exit(restore_move2_printing(), add = TRUE)

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  expect_invisible(tidytracks::tidytracks_printing(TRUE))
  expect_true(readRDS(path))
  expect_true(tidytracks::tidytracks_printing())

  expect_invisible(tidytracks::tidytracks_printing(FALSE))
  expect_false(readRDS(path))
  expect_false(tidytracks::tidytracks_printing())
})


test_that("non-sticky settings affect only the current session", {
  on.exit(restore_move2_printing(), add = TRUE)

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  # Establish a sticky FALSE preference.
  expect_invisible(tidytracks::tidytracks_printing(FALSE))
  expect_false(readRDS(path))

  # Override it for this session without changing the stored preference.
  expect_invisible(tidytracks::tidytracks_printing(TRUE, sticky = FALSE))
  expect_true(tidytracks::tidytracks_printing())
  expect_false(readRDS(path))

  # And switch back for this session, again without touching the file.
  expect_invisible(tidytracks::tidytracks_printing(FALSE, sticky = FALSE))
  expect_false(tidytracks::tidytracks_printing())
  expect_false(readRDS(path))
})


test_that("stored preference is restored on load", {
  on.exit(restore_move2_printing(), add = TRUE)

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  saveRDS(TRUE, path)
  tidytracks:::.onLoad(NULL, "tidytracks")
  expect_true(tidytracks::tidytracks_printing())

  saveRDS(FALSE, path)
  tidytracks:::.onLoad(NULL, "tidytracks")
  expect_false(tidytracks::tidytracks_printing())
})


test_that("missing stored preference defaults to standard move2 printing", {
  on.exit(restore_move2_printing(), add = TRUE)

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  expect_false(file.exists(path))
  expect_false(tidytracks:::.get_tt_printing_stored())

  tidytracks:::.onLoad(NULL, "tidytracks")
  expect_false(tidytracks::tidytracks_printing())
})


test_that("invalid stored preference warns and defaults to standard printing", {
  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  saveRDS("not a logical value", path)

  expect_warning(
    value <- tidytracks:::.get_tt_printing_stored(),
    "configuration file is invalid"
  )
  expect_false(value)
})


test_that("tidytracks_print validates its arguments", {
  expect_error(
    tidytracks::tidytracks_printing(NA),
    "`value` must be TRUE or FALSE."
  )
  expect_error(
    tidytracks::tidytracks_printing("true"),
    "`value` must be TRUE or FALSE."
  )
  expect_error(
    tidytracks::tidytracks_printing(TRUE, sticky = NA),
    "`sticky` must be a single TRUE or FALSE."
  )
  expect_error(
    tidytracks::tidytracks_printing(TRUE, sticky = "true"),
    "`sticky` must be a single TRUE or FALSE."
  )
})


test_that("print function works correctly", {
  on.exit(restore_move2_printing(), add = TRUE)

  # This test only needs a session-local switch and must not touch the user's
  # persistent preference.
  tidytracks::tidytracks_printing(TRUE, sticky = FALSE)

  output <- capture.output(print(example_tt))

  expect_true(any(grepl("move2", output)))
  expect_true(any(grepl("show_meta", output)))
  expect_true(any(grepl("Simple feature", output)))
})
