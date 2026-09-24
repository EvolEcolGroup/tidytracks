# Tests for custom tidytracks printing
#
# These tests cover:
#   * every accepted true and false environment-variable spelling;
#   * case-insensitive and whitespace-tolerant parsing;
#   * invalid and empty environment-variable values;
#   * precedence of the environment variable over the stored preference;
#   * immediate switching of the registered S3 method;
#   * persistence of TRUE and FALSE preferences outside CRAN checks.
#
# Persistent-file tests are skipped on CRAN. They redirect the
# configuration helper to a temporary file, so local and CI runs never modify
# the developer's real tidytracks preference.

# Restore both the environment and S3 registration after each test. S3 method
# registration is process-global, so cleanup prevents one test affecting the
# next test or another package's tests.
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


test_that("all true environment-variable values are recognised", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  for (value in c("true", "1", "yes", "TRUE", "Yes", "  true  ")) {
    Sys.setenv(TIDYTRACKS_PRINTING = value)
    expect_true(tidytracks:::.get_tt_printing_env(), info = value)
    expect_true(tidytracks:::.get_tidytracks_printing(), info = value)
  }
})


test_that("all false environment-variable values are recognised", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  for (value in c("false", "0", "no", "FALSE", "No", "  false  ")) {
    Sys.setenv(TIDYTRACKS_PRINTING = value)
    expect_false(tidytracks:::.get_tt_printing_env(), info = value)
    expect_false(tidytracks:::.get_tidytracks_printing(), info = value)
  }
})


test_that("an unset environment variable has no override", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  Sys.unsetenv("TIDYTRACKS_PRINTING")
  expect_true(is.na(tidytracks:::.get_tt_printing_env()))
})


test_that("invalid environment values warn and are ignored", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  for (value in c("maybe", "2", "enabled")) {
    Sys.setenv(TIDYTRACKS_PRINTING = value)
    expect_warning(
      result <- tidytracks:::.get_tt_printing_env(),
      "Ignoring invalid value of TIDYTRACKS_PRINTING",
      info = value
    )
    expect_true(is.na(result), info = value)
  }
})


test_that("empty environment values are ignored", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  Sys.setenv(TIDYTRACKS_PRINTING = "")

  if (.Platform$OS.type == "windows") {
    expect_no_warning(
      result <- tidytracks:::.get_tt_printing_env()
    )
  } else {
    expect_warning(
      result <- tidytracks:::.get_tt_printing_env(),
      "Ignoring invalid value of TIDYTRACKS_PRINTING"
    )
  }

  expect_true(is.na(result))
})


test_that("environment variable overrides either stored value", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  # Mock only the stored-value reader. This test therefore exercises the
  # precedence logic without reading or writing any persistent file.
  testthat::local_mocked_bindings(
    .get_tt_printing_stored = function() FALSE,
    .package = "tidytracks"
  )
  Sys.setenv(TIDYTRACKS_PRINTING = "true")
  expect_true(tidytracks:::.get_tidytracks_printing())

  testthat::local_mocked_bindings(
    .get_tt_printing_stored = function() TRUE,
    .package = "tidytracks"
  )
  Sys.setenv(TIDYTRACKS_PRINTING = "false")
  expect_false(tidytracks:::.get_tidytracks_printing())
})


test_that("invalid environment value falls back to stored preference", {
  old <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old)
      }
    },
    add = TRUE
  )

  testthat::local_mocked_bindings(
    .get_tt_printing_stored = function() TRUE,
    .package = "tidytracks"
  )

  Sys.setenv(TIDYTRACKS_PRINTING = "invalid")
  expect_warning(
    expect_true(tidytracks:::.get_tidytracks_printing()),
    "Ignoring invalid value of TIDYTRACKS_PRINTING"
  )
})


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


test_that("persistent TRUE preference is saved and read", {
  skip_on_cran()

  old_env <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old_env)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old_env)
      }
    },
    add = TRUE
  )
  on.exit(restore_move2_printing(), add = TRUE)
  Sys.unsetenv("TIDYTRACKS_PRINTING")

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  expect_invisible(tidytracks::tidytracks_printing(TRUE))
  expect_true(readRDS(path))
  expect_true(tidytracks::tidytracks_printing())

  custom <- get(
    "print_move2_tt",
    envir = asNamespace("tidytracks"),
    inherits = FALSE
  )
  expect_identical(utils::getS3method("print", "move2"), custom)
})


test_that("persistent FALSE preference is saved and read", {
  skip_on_cran()

  old_env <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old_env)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old_env)
      }
    },
    add = TRUE
  )
  on.exit(restore_move2_printing(), add = TRUE)
  Sys.unsetenv("TIDYTRACKS_PRINTING")

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  expect_invisible(tidytracks::tidytracks_printing(FALSE))
  expect_false(readRDS(path))
  expect_false(tidytracks::tidytracks_printing())

  original <- get(
    "print.move2",
    envir = asNamespace("move2"),
    inherits = FALSE
  )
  expect_identical(utils::getS3method("print", "move2"), original)
})


test_that("environment override wins while setter still saves preference", {
  skip_on_cran()

  old_env <- Sys.getenv("TIDYTRACKS_PRINTING", unset = NA_character_)
  on.exit(
    {
      if (is.na(old_env)) {
        Sys.unsetenv("TIDYTRACKS_PRINTING")
      } else {
        Sys.setenv(TIDYTRACKS_PRINTING = old_env)
      }
    },
    add = TRUE
  )
  on.exit(restore_move2_printing(), add = TRUE)

  path <- tempfile(fileext = ".rds")
  testthat::local_mocked_bindings(
    .tt_printing_config_file = function() path,
    .package = "tidytracks"
  )

  Sys.setenv(TIDYTRACKS_PRINTING = "true")
  expect_invisible(tidytracks::tidytracks_printing(FALSE))

  # FALSE is sticky on disk, but the current effective setting is TRUE.
  expect_false(readRDS(path))
  expect_true(tidytracks::tidytracks_printing())

  custom <- get(
    "print_move2_tt",
    envir = asNamespace("tidytracks"),
    inherits = FALSE
  )
  expect_identical(utils::getS3method("print", "move2"), custom)

  # Removing the override reveals the saved FALSE preference.
  Sys.unsetenv("TIDYTRACKS_PRINTING")
  expect_false(tidytracks::tidytracks_printing())
})
