#' Flag events to keep when thinning tracks by distance travelled
#'
#' This function selects, within each track, events spaced by the distance
#' travelled along the track. It is a wrapper around
#' [move2utils::mt_thin_distance()], which requires the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' Two methods are available:
#' * `method = "step"` (the default) keeps the first event of each track, and
#'   then the first event at which the distance travelled since the last kept
#'   event reaches `distance`. Consecutive kept events are therefore at least
#'   `distance` apart along the track (and can be further apart, as no new
#'   locations are interpolated).
#' * `method = "interval"` keeps the largest subset of events such that the
#'   distance travelled between consecutive kept events is `distance` (plus or
#'   minus `tolerance`); it is the equivalent of [event_flag_thin_time()] for
#'   distances. Tracks are split at any step longer than
#'   `distance + tolerance`, and the first event is not necessarily kept.
#'
#' Distances are great-circle distances for longitude/latitude coordinates, and
#' planar distances for projected coordinates. Events without a location are
#' ignored when measuring distances, and are never kept. To remove the events
#' that are not kept, use [tt_thin_distance()].
#'
#' @param x A `move2` object.
#' @param distance The target distance travelled between consecutive kept
#'   events, as a `units` object (e.g. `as_units(500, "m")`).
#' @param tolerance Only used with `method = "interval"`: the accepted
#'   deviation from `distance`, as a `units` object with length units. Defaults
#'   to `distance / 10`.
#' @param method The thinning method, either "step" (the default) or
#'   "interval" (see Details).
#' @param criterion Only used with `method = "interval"`: how to choose among
#'   subsets with the same number of events. "closest" (the default) keeps the
#'   subset whose distances deviate least from `distance` in total, "first"
#'   keeps the subset that starts earliest.
#' @returns A logical vector with one value per event of `x`, `TRUE` for the
#'   events to keep.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # keep events at least 200 km apart along each track
#' event_flag_thin_distance(example_tt, distance = as_units(200, "km"))
event_flag_thin_distance <- function(
  x,
  distance,
  tolerance = NULL,
  method = c("step", "interval"),
  criterion = c("closest", "first")
) {
  check_move2utils("event_flag_thin_distance") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  distance <- to_metres(distance, "distance")
  if (!is.null(tolerance)) {
    tolerance <- to_metres(tolerance, "tolerance", allow_zero = TRUE)
  }
  method <- match.arg(method)
  criterion <- match.arg(criterion)

  res <- call_move2utils( # nolint: object_usage_linter.
    x,
    move2utils::mt_thin_distance,
    distance = distance,
    tolerance = tolerance,
    method = method,
    criterion = criterion,
    cols = "thin_selected"
  )
  # events without a location are not passed to move2utils, and not kept
  res$thin_selected & !is.na(res$thin_selected)
}

#' Convert a units object with length units to a number of metres
#'
#' @param x A `units` object of length 1 with length units.
#' @param arg The name of the argument, used in error messages.
#' @param allow_zero Logical, whether a value of 0 is allowed.
#' @returns The value of `x` in metres, as a number.
#' @keywords internal
#' @noRd
to_metres <- function(x, arg, allow_zero = FALSE) {
  if (!inherits(x, "units") || length(x) != 1) {
    stop(arg, " must be a units object of length 1: e.g. as_units(500, 'm')")
  }
  out <- tryCatch(
    as.numeric(units::set_units(x, "m", mode = "standard")),
    error = function(e) {
      stop(
        arg, " must have units of length; got '", units::deparse_unit(x), "'"
      )
    }
  )
  if (!is.finite(out) || out < 0 || (!allow_zero && out == 0)) {
    stop(arg, " must be a positive distance")
  }
  out
}
