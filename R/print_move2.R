# ============================================================================
# Custom tidytracks printing for move2 objects
#
# This file controls whether objects of class `move2` are printed using:
#
#   1. the custom tidytracks method, `print_move2_tt()`, or
#   2. the original `print.move2()` method supplied by move2.
#
# Users can set a persistent preference with tidytracks_printing(TRUE/FALSE)
#
# The environment variable TIDYTRACKS_PRINTING can temporarily override that
# preference. The order of precedence is:
#
#   1. TIDYTRACKS_PRINTING, when set to a recognised value;
#   2. the persistent preference saved by tidytracks_printing();
#   3. FALSE, the package default.
#
# Recognised environment-variable values are, ignoring case and whitespace:
#
#   TRUE:  "true", "1", "yes"
#   FALSE: "false", "0", "no"
#
# An invalid environment-variable value generates a warning and is ignored.
# The persistent preference, or the package default, is then used.
#
# Changing the persistent preference takes effect immediately. If an
# environment-variable override is present, the persistent preference is still
# saved, but the environment variable continues to determine the effective
# method for that R process.
#
# IMPORTANT IMPLEMENTATION DETAIL
# --------------------------------
#
# We do not call move2's print.move2() directly. That method uses NextMethod(),
# which requires a valid S3 dispatch context. Instead, the chosen function is
# registered as the active print.move2 method. A subsequent print(x) call then
# reaches it through ordinary S3 dispatch.
# ============================================================================

# ============================================================================
# Configuration location
# ============================================================================

#' Path to the tidytracks printing configuration file
#'
#' Returns the internal path used to store the persistent tidytracks printing
#' preference.
#'
#' The file is placed in the platform-specific, package-specific configuration
#' directory returned by [tools::R_user_dir()]. tidytracks does not modify the
#' user's `.Rprofile` or `.Renviron`.
#'
#' @return A character scalar containing the configuration-file path.
#'
#' @keywords internal
.tt_printing_config_file <- function() {
  file.path(
    tools::R_user_dir(
      package = "tidytracks",
      which = "config"
    ),
    "tidytracks_printing.rds"
  )
}


# ============================================================================
# Environment-variable parsing
# ============================================================================

#' Read the TIDYTRACKS_PRINTING environment-variable override
#'
#' Parses the optional `TIDYTRACKS_PRINTING` environment variable.
#'
#' Recognised true values are `"true"`, `"1"`, and `"yes"`. Recognised false
#' values are `"false"`, `"0"`, and `"no"`. Matching is case-insensitive and
#' surrounding whitespace is ignored.
#'
#' If the variable is unset, `NA` is returned. If it is set to an unrecognised
#' value, a warning is emitted and `NA` is returned, allowing the caller to
#' fall back to the persistent preference.
#'
#' @return `TRUE`, `FALSE`, or `NA` when no valid override is present.
#'
#' @keywords internal
.get_tt_printing_env <- function() {
  value <- Sys.getenv(
    "TIDYTRACKS_PRINTING",
    unset = NA_character_
  )

  # Distinguish an unset variable from a variable explicitly set to an empty
  # string. The latter is invalid and should produce the same warning as any
  # other unrecognised value.
  if (is.na(value)) {
    return(NA)
  }

  normalised <- tolower(trimws(value))

  if (normalised %in% c("true", "1", "yes")) {
    return(TRUE)
  }

  if (normalised %in% c("false", "0", "no")) {
    return(FALSE)
  }

  warning(
    paste0(
      "Ignoring invalid value of TIDYTRACKS_PRINTING: ",
      sQuote(value),
      ". Expected one of true, false, 1, 0, yes, or no."
    ),
    call. = FALSE
  )

  NA
}


# ============================================================================
# Persistent preference
# ============================================================================

#' Read the persistent tidytracks printing preference
#'
#' Reads the preference previously saved by [tidytracks_printing()]. This
#' helper deliberately does not inspect `TIDYTRACKS_PRINTING`; it returns only
#' the stored preference.
#'
#' If no preference has been stored, the package default of `FALSE` is
#' returned. A missing, damaged, or invalid configuration file therefore never
#' prevents tidytracks from loading.
#'
#' @return A single logical value.
#'
#' @keywords internal
.get_tt_printing_stored <- function() {
  config_file <- .tt_printing_config_file()

  if (!file.exists(config_file)) {
    return(FALSE)
  }

  value <- tryCatch(
    readRDS(config_file),
    error = function(e) NULL
  )

  if (
    is.logical(value) &&
      length(value) == 1L &&
      !is.na(value)
  ) {
    return(value)
  }

  warning(
    paste0(
      "The tidytracks printing configuration file is invalid:\n",
      config_file,
      "\n\nUsing standard move2 printing."
    ),
    call. = FALSE
  )

  FALSE
}


# ============================================================================
# Effective preference
# ============================================================================

#' Get the effective tidytracks printing preference
#'
#' Resolves the printing preference using the following precedence:
#'
#' 1. a valid `TIDYTRACKS_PRINTING` environment-variable override;
#' 2. the persistent preference saved by [tidytracks_printing()];
#' 3. the package default, `FALSE`.
#'
#' An invalid environment-variable value is ignored after a warning, so that
#' it cannot prevent the stored preference from being used.
#'
#' @return A single logical value.
#'
#' @keywords internal
.get_tidytracks_printing <- function() {
  env_value <- .get_tt_printing_env()

  if (!is.na(env_value)) {
    return(env_value)
  }

  .get_tt_printing_stored()
}


# ============================================================================
# S3 method registration
# ============================================================================

#' Register the selected print method for move2 objects
#'
#' Switches the S3 `print()` method currently registered for class `move2`.
#'
#' If `value` is `TRUE`, tidytracks' `print_move2_tt()` implementation is
#' registered. If `value` is `FALSE`, the original function stored in the
#' `move2` namespace is registered.
#'
#' Re-registering the original method, rather than calling it directly, is
#' essential because move2's method uses `NextMethod()`. Registration ensures
#' that the function is entered through normal S3 dispatch and receives the
#' required dispatch context.
#'
#' @param value A single non-missing logical value. `TRUE` selects custom
#'   tidytracks printing and `FALSE` selects standard move2 printing.
#'
#' @return `NULL`, invisibly.
#'
#' @keywords internal
.set_tidytracks_printing <- function(value) {
  if (
    !is.logical(value) ||
      length(value) != 1L ||
      is.na(value)
  ) {
    stop(
      "`value` must be a single TRUE or FALSE.",
      call. = FALSE
    )
  }

  if (value) {
    # Use tidytracks' implementation. This function is intentionally not
    # registered through NAMESPACE because its registration must be switchable
    # while R is running.
    method <- print_move2_tt
  } else {
    # Retrieve the function defined inside move2's namespace. Do not use
    # getS3method("print", "move2") here because that returns whichever method
    # is currently registered, which may already be the tidytracks method.
    method <- get(
      "print.move2",
      envir = asNamespace("move2"),
      inherits = FALSE
    )
  }

  # print() is defined by base, so its S3 method table is associated with the
  # base namespace. Registering another print/move2 combination replaces the
  # function selected for subsequent S3 dispatch.
  registerS3method(
    genname = "print",
    class = "move2",
    method = method,
    envir = asNamespace("base")
  )

  invisible(NULL)
}


# ============================================================================
# Public interface
# ============================================================================

#' Enable or disable custom tidytracks printing
#'
#' Controls whether objects of class `move2` use custom tidytracks printing or
#' the standard printing method supplied by `move2`.
#'
#' @param value Either `TRUE`, `FALSE`, or `NULL`.
#'
#'   * `TRUE` saves a preference for custom tidytracks printing.
#'   * `FALSE` saves a preference for standard move2 printing.
#'   * `NULL`, the default, returns the current effective setting without
#'     changing the persistent preference.
#'
#' @details
#' The preference saved by this function is persistent across R sessions and
#' is stored in the user-specific tidytracks configuration directory returned
#' by [tools::R_user_dir()].
#'
#' A `TIDYTRACKS_PRINTING` environment variable can temporarily override the
#' stored preference. Accepted values are `"true"`, `"1"`, and `"yes"` for
#' custom tidytracks printing, and `"false"`, `"0"`, and `"no"` for standard
#' move2 printing. Values are matched without regard to case, and surrounding
#' whitespace is ignored.
#'
#' The order of precedence is:
#'
#' 1. `TIDYTRACKS_PRINTING`, when it contains a recognised value;
#' 2. the persistent preference saved by this function;
#' 3. `FALSE`, the package default.
#'
#' Calling `tidytracks_printing(TRUE)` or `tidytracks_printing(FALSE)` always
#' saves the supplied persistent preference. It then immediately registers the
#' method selected by the effective setting. Thus, if an environment-variable
#' override is present, that override continues to control printing without
#' changing the saved preference.
#'
#' Changing `TIDYTRACKS_PRINTING` with [Sys.setenv()] after tidytracks has been
#' loaded does not by itself re-register an S3 method. Call
#' `tidytracks_printing()` to inspect the new effective value, then call
#' `tidytracks_printing(TRUE)` or `tidytracks_printing(FALSE)` to apply and save
#' a preference, or reload tidytracks. At package load, `.onLoad()` always
#' applies the current effective setting.
#'
#' @return
#' If `value` is `NULL`, a logical scalar giving the effective setting after
#' applying the environment-variable override.
#'
#' If `value` is `TRUE` or `FALSE`, the supplied value is saved and returned
#' invisibly. The S3 method corresponding to the effective setting is
#' registered immediately.
#'
#' @examples
#' \dontrun{
#' # Inspect the effective setting
#' tidytracks_printing()
#'
#' # Persistently enable custom tidytracks printing
#' tidytracks_printing(TRUE)
#'
#' # Persistently restore standard move2 printing
#' tidytracks_printing(FALSE)
#'
#' # Temporarily override the stored preference for this R process
#' Sys.setenv(TIDYTRACKS_PRINTING = "true")
#' tidytracks_printing()
#'
#' # Remove the temporary override
#' Sys.unsetenv("TIDYTRACKS_PRINTING")
#' }
#'
#' @export
tidytracks_printing <- function(value = NULL) {
  # With no argument, report the effective value. This includes any valid
  # environment-variable override.
  if (is.null(value)) {
    return(.get_tidytracks_printing())
  }

  if (
    !is.logical(value) ||
      length(value) != 1L ||
      is.na(value)
  ) {
    stop(
      "`value` must be TRUE or FALSE.",
      call. = FALSE
    )
  }

  config_file <- .tt_printing_config_file()

  # R_user_dir() determines the correct directory but does not create it.
  dir.create(
    dirname(config_file),
    recursive = TRUE,
    showWarnings = FALSE
  )

  # Save the requested persistent preference even when an environment variable
  # currently overrides it. Once the override is removed, this value becomes
  # effective again.
  saveRDS(value, config_file)

  # Apply the effective setting, not necessarily the value just saved. This is
  # what gives TIDYTRACKS_PRINTING precedence over the sticky preference.
  .set_tidytracks_printing(
    .get_tidytracks_printing()
  )

  invisible(value)
}


# ============================================================================
# tidytracks print implementation
# ============================================================================

#' Print move2 objects using tidytracks
#'
#' Internal implementation used when custom tidytracks printing is enabled.
#'
#' This function is registered dynamically as the S3 `print()` method for
#' class `move2`. It must not have an `@export` or `@method` tag because doing
#' so would add an unconditional `S3method(print,move2)` entry to NAMESPACE.
#'
#' @param x An object of class `move2`.
#' @param ... Additional arguments passed to the next print method.
#' @param n Maximum number of rows to print. Defaults to the `sf_max_print`
#'   option, or 10 when that option is unset.
#'
#' @return `x`, invisibly.
#'
#' @keywords internal
print_move2_tt <- function(
  x,
  ...,
  n = getOption("sf_max_print", default = 10L)
) {
  avg_dur <- mean(     # nolint: object_usage_linter.
    do.call(
      c,
      lapply(
        lapply(
          split(
            move2::mt_time(x),
            move2::mt_track_id(x),
            drop = TRUE
          ),
          range
        ),
        diff
      )
    )
  )

  cat(
    cli::format_message(
      paste0(
        "A {.cls move2} with `track_id_column` ",
        "{.val {move2::mt_track_id_column(x)}} and `time_column` ",
        "{.val {move2::mt_time_column(x)}}"
      )
    ),
    "\n",
    sep = ""
  )

  cat(
    cli::format_message(
      paste0(
        "Containing {move2::mt_n_tracks(x)} track{?s} lasting ",
        "{?on average} {format(avg_dur, digits = 3)} in a"
      )
    ),
    "\n",
    sep = ""
  )

  # Because this function is registered as print.move2, NextMethod() has the
  # S3 dispatch context it requires.
  NextMethod(n = n)

  cat(
    cli::format_message(
      "To see track metadata, use `show_meta()`"
    ),
    "\n",
    sep = ""
  )

  invisible(x)
}


# ============================================================================
# Package-load hook
# ============================================================================

#' tidytracks namespace load hook
#'
#' Applies the effective printing preference whenever tidytracks is loaded.
#'
#' Because `move2` is a dependency, its namespace and original `print.move2`
#' implementation are already available when this hook runs.
#'
#' @param libname Library path supplied automatically by R.
#' @param pkgname Package name supplied automatically by R.
#'
#' @return `NULL`, invisibly.
#'
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  .set_tidytracks_printing(
    .get_tidytracks_printing()
  )

  invisible(NULL)
}
