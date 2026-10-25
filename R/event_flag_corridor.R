#' Flag the steps that are part of movement corridors
#'
#' This function detects corridors: places where animals move fast, in a
#' consistent direction (either way along the corridor). It is a wrapper
#' around [move2utils::mt_corridor()], which requires the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' The nearby steps of a step (from an event to the next one in the same
#' track) are the steps whose midpoints are within half its length of its
#' midpoint, including the step itself. A step is a candidate if it is fast
#' (`speed_threshold`), and if its nearby steps run in a similar direction
#' (`circvar_threshold`). A step is then flagged as part of a corridor if it
#' has at least `min_segments` nearby steps, and if more than half of them are
#' candidates; a step that is not a candidate itself (e.g. a slow step) can
#' therefore be flagged when it lies within a corridor.
#'
#' When `speed_threshold` or `circvar_threshold` are not given, they are
#' estimated from all the steps in `x` (pooling all tracks), with a warning
#' giving the value used; give explicit values to compare corridors among
#' datasets.
#'
#' The search radius depends on the length of the steps, so it assumes
#' roughly regular sampling; `move2utils` warns when the time intervals are
#' very irregular.
#'
#' `x` must be ordered by time within each track (see [tt_order_time()]).
#' Events without a location are ignored, and get `NA`.
#'
#' @param x A `move2` object.
#' @param speed_threshold The speed at or above which a step is fast, as a
#'   `units` object (e.g. `as_units(1, "m/s")`). Defaults to the upper
#'   quartile of the speeds of the steps.
#' @param circvar_threshold A number between 0 and 1: the circular variance of
#'   the directions of the nearby steps at or below which they are considered
#'   to run in a similar direction. Defaults to the lower quartile of the
#'   circular variances.
#' @param min_segments The minimum number of nearby steps (including the step
#'   itself) for a step to be part of a corridor.
#' @returns A logical vector with one value per event of `x`, `TRUE` for the
#'   events whose next step is part of a corridor (the last event of each
#'   track is `FALSE`).
#' @references Based on the `corridor()` function of the `move` package, see
#'   LaPoint, S., Gallery, P., Wikelski, M. & Kays, R. (2013). Animal behavior,
#'   cost-based corridor models, and real corridors. *Landscape Ecology*, 28,
#'   1615-1630. \doi{10.1007/s10980-013-9910-0}
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' event_flag_corridor(
#'   example_tt,
#'   speed_threshold = as_units(5, "m/s"),
#'   circvar_threshold = 0.5,
#'   min_segments = 1
#' )
event_flag_corridor <- function(
  x,
  speed_threshold = NULL,
  circvar_threshold = NULL,
  min_segments = 2
) {
  check_move2utils("event_flag_corridor") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # step lengths (and so the search radii) and speeds are computed in metres,
  # which needs a CRS
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  # mt_corridor() uses step lengths in metres as search radii on projected
  # coordinates, so these must be in metres
  check_metric_crs(x) # nolint: object_usage_linter.
  # mt_corridor() compares every step with these values without checking
  # their length, so a vector would be silently recycled along the steps
  if (
    length(speed_threshold) > 1 ||
      length(circvar_threshold) > 1 ||
      length(min_segments) != 1
  ) {
    stop(
      "speed_threshold, circvar_threshold and min_segments must be single ",
      "values"
    )
  }
  # speed_threshold is in the move2utils_units table, so units_to_move2utils()
  # both checks that it is a speed and converts it to the m/s expected by
  # mt_corridor(); NULL stays NULL, so that mt_corridor() estimates it.
  # circvar_threshold (unitless) and min_segments (a count) need no conversion
  speed_threshold <- units_to_move2utils( # nolint: object_usage_linter.
    list(speed_threshold = speed_threshold)
  )$speed_threshold

  # the warnings of mt_corridor() (estimated thresholds, irregular sampling)
  # are left to reach the user
  res <- call_move2utils( # nolint: object_usage_linter.
    x,
    move2utils::mt_corridor,
    speed_threshold = speed_threshold,
    circvar_threshold = circvar_threshold,
    min_segments = min_segments,
    cols = "corridor"
  )
  # corridor is a factor with levels "corridor" and "not corridor"; the last
  # event of each track (which starts no step) is "not corridor", and events
  # without a location, which call_move2utils() does not pass to move2utils,
  # are NA (mt_corridor() would have called them "not corridor", but they
  # start no step)
  res$corridor == "corridor"
}
