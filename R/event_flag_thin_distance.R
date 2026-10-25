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
#' ignored when measuring distances, and are never kept. `x` must be ordered
#' by time within each track (see [tt_order_time()]). To remove the events
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
  # move2utils measures the steps with mt_distance(units = "m"), which needs a
  # CRS to know whether to use great-circle or planar distances
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  # both are converted to metres here, as mt_thin_distance() takes metres;
  # a tolerance of 0 is valid (exact distances only), a distance of 0 is not
  distance <- to_metres(distance, "distance")
  if (!is.null(tolerance)) {
    tolerance <- to_metres(tolerance, "tolerance", allow_zero = TRUE)
  }
  # matched here (as well as in move2utils) so that invalid values give the
  # usual match.arg() error before any work is done
  method <- match.arg(method)
  criterion <- match.arg(criterion)

  # the distance travelled is the sum of the steps between consecutive rows,
  # so (unlike for mt_thin_time()) the rows must be ordered by time, which
  # call_move2utils() checks by default. a tolerance given with the step
  # method is passed on anyway, so that move2utils warns that it is ignored;
  # a tolerance larger than distance is rejected by move2utils
  res <- call_move2utils( # nolint: object_usage_linter.
    x,
    move2utils::mt_thin_distance,
    distance = distance,
    tolerance = tolerance,
    method = method,
    criterion = criterion,
    cols = "thin_selected"
  )
  # events without a location are not passed to move2utils (so distances are
  # measured from the previous to the next location) and come back as NA:
  # they are never kept, as a thinned track should only contain locations
  res$thin_selected %in% TRUE
}

#' Convert a units object with length units to a number of metres
#'
#' Also used by `hr_tt_dbbmm()` for its raster resolution.
#'
#' @param x A `units` object of length 1 with length units.
#' @param arg The name of the argument, used in error messages.
#' @param allow_zero Logical, whether a value of 0 is allowed.
#' @returns The value of `x` in metres, as a number.
#' @keywords internal
#' @noRd
to_metres <- function(x, arg, allow_zero = FALSE) {
  # plain numbers are rejected rather than assumed to be in metres, as in the
  # rest of tidytracks physical quantities must carry their units
  if (!inherits(x, "units") || length(x) != 1) {
    stop(arg, " must be a units object of length 1: e.g. as_units(500, 'm')")
  }
  # mode = "standard" takes the unit from the string "m" (the default mode
  # expects a unit symbol); set_units() gives an error for units that are not
  # lengths, which is replaced by a plainer message
  out <- tryCatch(
    as.numeric(units::set_units(x, "m", mode = "standard")),
    error = function(e) {
      stop(
        arg, " must have units of length; got '", units::deparse_unit(x), "'"
      )
    }
  )
  # also rejects NA, which would otherwise reach move2utils
  if (!is.finite(out) || out < 0 || (!allow_zero && out == 0)) {
    stop(arg, " must be a positive distance")
  }
  out
}
