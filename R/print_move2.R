# ============================================================================
# Custom tidytracks printing for move2 objects
# ============================================================================

#' Path to the tidytracks printing configuration file
#'
#' Returns the internal path used to store the persistent tidytracks printing
#' preference.
#'
#' @return A character scalar containing the configuration-file path.
#' @keywords internal
.tt_printing_config_file <- function() {
  file.path(
    tools::R_user_dir(package = "tidytracks", which = "config"),
    "tidytracks_printing.rds"
  )
}

#' Read the persistent tidytracks printing preference
#'
#' @return A single logical value. If no valid stored preference exists,
#'   `FALSE` is returned.
#' @keywords internal
.get_tt_printing_stored <- function() {
  config_file <- .tt_printing_config_file()

  if (!file.exists(config_file)) {
    return(FALSE)
  }

  value <- tryCatch(readRDS(config_file), error = function(e) NULL)

  if (is.logical(value) && length(value) == 1L && !is.na(value)) {
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

#' Register the selected print method for move2 objects
#'
#' @param value A single non-missing logical value. `TRUE` selects custom
#'   tidytracks printing and `FALSE` selects standard move2 printing.
#' @return `NULL`, invisibly.
#' @keywords internal
.set_tidytracks_printing <- function(value) {
  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`value` must be a single TRUE or FALSE.", call. = FALSE)
  }

  if (value) {
    method <- print_move2_tt
  } else {
    method <- get(
      "print.move2",
      envir = asNamespace("move2"),
      inherits = FALSE
    )
  }

  registerS3method(
    genname = "print",
    class = "move2",
    method = method,
    envir = asNamespace("base")
  )

  invisible(NULL)
}

#' Check whether tidytracks printing is currently registered
#'
#' @return `TRUE` if `print_move2_tt()` is currently registered for
#'   `print.move2`; otherwise `FALSE`.
#' @keywords internal
.is_tt_print_registered <- function() {
  method <- utils::getS3method("print", "move2", optional = TRUE)

  if (is.null(method)) {
    return(FALSE)
  }

  identical(method, print_move2_tt)
}

#' Enable or disable custom tidytracks printing
#'
#' Controls whether objects of class `move2` use custom tidytracks printing or
#' the standard printing method supplied by `move2`.
#'
#' @param value Either `TRUE`, `FALSE`, or `NULL`. `TRUE` registers custom
#'   tidytracks printing, `FALSE` registers standard move2 printing, and `NULL`
#'   reports which method is currently registered without changing anything.
#' @param sticky Whether the supplied setting should persist across R sessions.
#'   If `FALSE`, the method is changed only for the current R session. If
#'   `TRUE`, the supplied value is also saved in the user-specific tidytracks
#'   configuration directory. Defaults to `TRUE`.
#'
#' @details Calling `tidytracks_printing()` with no `value` directly inspects
#'   the currently registered S3 method. It does not read the persistent
#'   configuration file.
#'
#' @return If `value` is `NULL`, a logical scalar indicating whether tidytracks'
#'   custom print method is currently registered. Otherwise, the supplied value
#'   is returned invisibly after registration.
#'
#' @examples
#' \dontrun{
#' tidytracks_printing()
#' tidytracks_printing(TRUE)
#' tidytracks_printing(FALSE)
#' tidytracks_printing(TRUE, sticky = FALSE)
#' tidytracks_printing(FALSE, sticky = FALSE)
#' }
#' @export
tidytracks_printing <- function(value = NULL, sticky = TRUE) {
  if (!is.logical(sticky) || length(sticky) != 1L || is.na(sticky)) {
    stop("`sticky` must be a single TRUE or FALSE.", call. = FALSE)
  }

  if (is.null(value)) {
    return(.is_tt_print_registered())
  }

  if (!is.logical(value) || length(value) != 1L || is.na(value)) {
    stop("`value` must be TRUE or FALSE.", call. = FALSE)
  }

  if (sticky) {
    config_file <- .tt_printing_config_file()
    dir.create(dirname(config_file), recursive = TRUE, showWarnings = FALSE)
    saveRDS(value, config_file)
  }

  .set_tidytracks_printing(value)
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
