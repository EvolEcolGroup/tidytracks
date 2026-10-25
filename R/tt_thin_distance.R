#' Thin tracks by distance travelled
#'
#' This function keeps, within each track, events spaced by the distance
#' travelled along the track, and removes the other events. It is a wrapper
#' around [move2utils::mt_thin_distance()], which requires the suggested
#' package `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`). See
#' [event_flag_thin_distance()] for details of the methods, and to flag the
#' events to keep without removing the others.
#'
#' @inheritParams event_flag_thin_distance
#' @returns The `move2` object `x` with only the kept events.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # keep events at least 200 km apart along each track
#' tt_thin_distance(example_tt, distance = as_units(200, "km"))
tt_thin_distance <- function(
  x,
  distance,
  tolerance = NULL,
  method = c("step", "interval"),
  criterion = c("closest", "first")
) {
  # all the checks are done by event_flag_thin_distance(); keep has no NA
  # (events without a location are FALSE), so it can be used directly to
  # subset x
  keep <- event_flag_thin_distance( # nolint: object_usage_linter.
    x,
    distance = distance,
    tolerance = tolerance,
    method = method,
    criterion = criterion
  )
  x[keep, ]
}
