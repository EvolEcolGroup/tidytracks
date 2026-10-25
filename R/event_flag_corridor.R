#' Flag the steps that are part of movement corridors
#'
#' This function detects corridors: places where animals move fast, in a
#' consistent direction (either way along the corridor). A step (from an event
#' to the next one in the same track) is flagged as part of a corridor if it is
#' fast, and if most of the nearby steps (the steps whose midpoints are within
#' half its length) are also fast and run in a similar direction. It is a
#' wrapper around [move2utils::mt_corridor()], which requires the suggested
#' package `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' When `speed_threshold` or `circvar_threshold` are not given, they are
#' estimated from all the steps in `x` (pooling all tracks), with a warning
#' giving the value used; give explicit values to compare corridors among
#' datasets.
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
#' @param min_segments The minimum number of nearby steps that must qualify
#'   for a step to be part of a corridor.
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
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  if (!is.null(speed_threshold)) {
    is_speed <- inherits(speed_threshold, "units") &&
      units::ud_are_convertible(units::deparse_unit(speed_threshold), "m/s")
    if (!is_speed) {
      stop("speed_threshold must be a units object: e.g. as_units(1, 'm/s')")
    }
  }

  args <- units_to_move2utils(list( # nolint: object_usage_linter.
    speed_threshold = speed_threshold,
    circvar_threshold = circvar_threshold,
    min_segments = min_segments
  ))
  res <- do.call(
    call_move2utils, # nolint: object_usage_linter.
    c(list(x, move2utils::mt_corridor), args, list(cols = "corridor"))
  )
  res$corridor == "corridor"
}
