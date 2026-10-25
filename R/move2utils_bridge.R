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

#' Check that a move2 object is ordered by time within each track
#'
#' Most `move2utils` functions work on the steps between consecutive events,
#' and assume that the events of each track are stored together and ordered by
#' time. Rather than reordering behind the scenes, the wrappers require an
#' ordered object and suggest [tt_order_time()].
#'
#' @param x A `move2` object.
#' @returns `NULL`, invisibly; gives an error if `x` is not ordered by time
#'   within each track.
#' @keywords internal
#' @noRd
check_time_ordered <- function(x) {
  # mt_is_time_ordered() returns FALSE if the times are not in order, but gives
  # an error if the events of a track are not stored together
  ordered <- tryCatch(
    move2::mt_is_time_ordered(x),
    error = function(e) FALSE
  )
  if (!isTRUE(ordered)) {
    stop(
      "x must be ordered by time within each track; ",
      "use tt_order_time(x) to order it"
    )
  }
  invisible(NULL)
}

#' Call a move2utils function and return event-level results
#'
#' Calls a `move2utils` function that returns its input `move2` object with
#' added columns, and returns the requested columns matched to the events of
#' `x`. `move2utils` gives an error for events without a location, whilst
#' tidytracks allows them: they are not passed to `fn`, and get `NA`.
#'
#' @param x A `move2` object.
#' @param fn A `move2utils` function whose first argument is a `move2` object
#'   and which returns that object with added columns.
#' @param ... Further arguments passed to `fn`.
#' @param cols Character vector of the columns of the output of `fn` to return.
#' @param time_ordered Logical, whether `fn` requires the events to be ordered
#'   by time within each track (see `check_time_ordered()`).
#' @returns A tibble with one row per event of `x` (in the same order) and the
#'   columns `cols`.
#' @keywords internal
#' @noRd
call_move2utils <- function(x, fn, ..., cols, time_ordered = TRUE) {
  if (time_ordered) {
    check_time_ordered(x)
  }
  located <- !sf::st_is_empty(x)
  args <- move2utils_args(fn, c(list(x[located, ]), list(...)))
  res <- do.call(fn, args)
  if (
    nrow(res) != sum(located) ||
      !identical(move2::mt_time(res), move2::mt_time(x)[located])
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
  # fill in the events that were not passed to move2utils with NA (indexing
  # each vector keeps its class, e.g. units or POSIXct)
  out <- lapply(cols, function(col) {
    values <- res[[col]]
    matched <- values[rep(NA_integer_, nrow(x))]
    matched[located] <- values
    matched
  })
  names(out) <- cols
  tibble::as_tibble(out)
}
