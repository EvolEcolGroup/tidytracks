#' Flag events to keep when thinning tracks to a time interval
#'
#' This function selects, within each track, the largest subset of events such
#' that consecutive selected events are separated by `interval` (plus or minus
#' `tolerance`). Unlike [tt_regular_time()], which interpolates new locations
#' on a regular time grid, this keeps a subset of the original events. It is a
#' wrapper around [move2utils::mt_thin_time()], which requires the suggested
#' package `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' Tracks are split at any gap longer than `interval + tolerance`: thinning
#' never bridges such a gap. When several subsets of the same size exist,
#' `criterion` decides which one is kept. Events without a location are never
#' kept. To remove the events that are not kept, use [tt_thin_time()].
#'
#' @param x A `move2` object.
#' @param interval The target time interval between consecutive kept events,
#'   as a `units` object (e.g. `as_units(1, "h")`).
#' @param tolerance The accepted deviation from `interval`, as a `units` object
#'   with time units. Defaults to `interval / 10`.
#' @param criterion How to choose among subsets with the same number of
#'   events: "closest" (the default) keeps the subset whose intervals deviate
#'   least from `interval` in total, "first" keeps the subset that starts
#'   earliest.
#' @returns A logical vector with one value per event of `x`, `TRUE` for the
#'   events to keep.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # keep events 40 minutes apart (events in example_tt are 20 minutes apart)
#' event_flag_thin_time(example_tt, interval = as_units(40, "min"))
event_flag_thin_time <- function(
  x,
  interval,
  tolerance = NULL,
  criterion = c("closest", "first")
) {
  check_move2utils("event_flag_thin_time") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  interval <- .to_seconds(interval, "interval") # nolint: object_usage_linter.
  if (!is.null(tolerance) && !inherits(tolerance, "units")) {
    stop("tolerance must be a units object: e.g. as_units(5, 'min')")
  }
  criterion <- match.arg(criterion)

  res <- call_move2utils( # nolint: object_usage_linter.
    x,
    move2utils::mt_thin_time,
    interval = interval,
    tolerance = tolerance,
    criterion = criterion,
    cols = "thin_selected"
  )
  # events without a location are not passed to move2utils, and not kept
  res$thin_selected & !is.na(res$thin_selected)
}
