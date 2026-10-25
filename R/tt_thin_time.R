#' Thin tracks to a time interval
#'
#' This function keeps, within each track, the largest subset of events such
#' that consecutive kept events are separated by `interval` (plus or minus
#' `tolerance`), and removes the other events. Unlike [tt_regular_time()],
#' which interpolates new locations on a regular time grid, this keeps a subset
#' of the original events. It is a wrapper around
#' [move2utils::mt_thin_time()], which requires the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`). See
#' [event_flag_thin_time()] for details, and to flag the events to keep
#' without removing the others.
#'
#' @inheritParams event_flag_thin_time
#' @returns The `move2` object `x` with only the kept events.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # keep events 40 minutes apart (events in example_tt are 20 minutes apart)
#' tt_thin_time(example_tt, interval = as_units(40, "min"))
tt_thin_time <- function(
  x,
  interval,
  tolerance = NULL,
  criterion = c("closest", "first")
) {
  # all the checks are done by event_flag_thin_time(); keep has no NA (events
  # without a location are FALSE), so it can be used directly to subset x
  keep <- event_flag_thin_time( # nolint: object_usage_linter.
    x,
    interval = interval,
    tolerance = tolerance,
    criterion = criterion
  )
  x[keep, ]
}
