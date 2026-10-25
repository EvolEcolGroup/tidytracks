#' Check that move2utils is installed
#'
#' Functions that wrap `move2utils` call this first. `move2utils` is a
#' suggested package that is not on CRAN, so the error explains how to install
#' it from GitHub.
#'
#' @param fn Name of the calling function, used in the error message.
#' @returns `NULL`, invisibly; gives an error if `move2utils` is not installed.
#' @keywords internal
#' @noRd
check_move2utils <- function(fn) {
  if (!is_move2utils_installed()) {
    stop(
      fn, "() requires the suggested package 'move2utils'. ",
      "Install it with remotes::install_github('move2universe/move2utils')."
    )
  }
  invisible(NULL)
}

#' Check whether move2utils is installed (a separate function so that it can
#' be mocked in tests)
#' @keywords internal
#' @noRd
is_move2utils_installed <- function() {
  requireNamespace("move2utils", quietly = TRUE)
}

#' Set the defaults used when tidytracks calls a move2utils function
#'
#' Many `move2utils` functions draw a plot and print a narrative by default.
#' tidytracks wrappers return values instead, so `plot = FALSE` and
#' `silent = TRUE` are set for any function that has these arguments, unless
#' they are already in `args`.
#'
#' @param fn A `move2utils` function.
#' @param args A named list of arguments for `fn`.
#' @returns `args`, with `plot` and `silent` added where relevant.
#' @keywords internal
#' @noRd
move2utils_args <- function(fn, args) {
  fn_args <- names(formals(fn))
  if ("plot" %in% fn_args && is.null(args$plot)) {
    args$plot <- FALSE
  }
  if ("silent" %in% fn_args && is.null(args$silent)) {
    args$silent <- TRUE
  }
  args
}

#' Prepare a move2 object for move2utils
#'
#' `move2utils` gives an error for events without a location, and expects the
#' events to be ordered by time within each track, whilst tidytracks allows
#' both. This drops events with an empty geometry and orders the remaining
#' ones by time, storing the original position of each event in the column
#' `.tt_row` so that results can be matched back with `call_move2utils()`.
#'
#' @param x A `move2` object.
#' @returns `x`, without events with an empty geometry, ordered by time within
#'   each track, and with the additional integer column `.tt_row`.
#' @keywords internal
#' @noRd
prepare_for_move2utils <- function(x) {
  x$.tt_row <- seq_len(nrow(x))
  x <- x[!sf::st_is_empty(x), ]
  tt_order_time(x) # nolint: object_usage_linter.
}

#' Call a move2utils function and return event-level results
#'
#' Calls a `move2utils` function that returns its input `move2` object with
#' added columns, and returns the requested columns matched to the events of
#' `x`. Events without a location are not passed to `fn` and get `NA`.
#'
#' @param x A `move2` object.
#' @param fn A `move2utils` function whose first argument is a `move2` object
#'   and which returns that object with added columns.
#' @param ... Further arguments passed to `fn`.
#' @param cols Character vector of the columns of the output of `fn` to return.
#' @returns A tibble with one row per event of `x` (in the same order) and the
#'   columns `cols`.
#' @keywords internal
#' @noRd
call_move2utils <- function(x, fn, ..., cols) {
  x_prep <- prepare_for_move2utils(x)
  args <- move2utils_args(fn, c(list(x_prep), list(...)))
  res <- do.call(fn, args)
  if (
    nrow(res) != nrow(x_prep) ||
      !identical(res$.tt_row, x_prep$.tt_row)
  ) {
    stop("move2utils did not return one row for each event, in order")
  }
  missing_cols <- setdiff(cols, names(res))
  if (length(missing_cols) > 0) {
    stop(
      "move2utils did not return the column(s): ",
      paste(missing_cols, collapse = ", ")
    )
  }
  # match each column back to the original events, filling in the events that
  # were not passed to move2utils with NA (indexing each vector keeps its
  # class, e.g. units or POSIXct)
  out <- lapply(cols, function(col) {
    values <- res[[col]]
    matched <- values[rep(NA_integer_, nrow(x))]
    matched[res$.tt_row] <- values
    matched
  })
  names(out) <- cols
  tibble::as_tibble(out)
}
