#' Clean a `move2` object using McConnell's algorithm
#'
#' This function cleans a `move2` object using McConnell's algorithm. It removes
#' outliers based on the distance between consecutive points and the time
#' interval between them (see [event_flag_mcconnell()] for details of the
#' algorithm, by McConnell et al. 1992). This function
#' returns a clean `move2` object; to generate a column that flags events to
#' remove but does not remove them, use `event_flag_mcconnell()`.
#'
#' @param x A move2 object
#' @param max_speed speed, provided as a `units` object (e.g.
#' as_units(50, 'm/s').
#' @param flag_action One of "remove", "null", or "interpolate", to either
#' remove the points flagged by the algorithm, keep the time stamp but set
#' location to NULL, or replace the location with a linearly interpolated
#' location from the events that were not filtered out.
#' @param check_first_last Logical. If `TRUE`, also evaluate the first and last
#'   currently valid point of each track using the endpoint RMS described in
#'   [event_flag_mcconnell()]. If either endpoint is removed, the McConnell
#'   filter is rerun on the reduced track until the result is stable.
#' @return The `move2` object `x`, with the flagged events removed, or with
#'   their location set to empty or interpolated (see `flag_action`).
#' @export
#' @examples
#' # this removes 3 events from the example dataset
#' tt_clean_mcconnell(example_tt,
#'   max_speed = as_units(50, "km/h"),
#'   flag_action = "remove"
#' )
tt_clean_mcconnell <- function(
  x,
  max_speed = NULL,
  flag_action = c("remove", "interpolate", "null"),
  check_first_last = FALSE
) {
  # checking for appropriate x and max_speed is done by event_flag_mcconnell
  flag_action <- match.arg(flag_action)

  # Call the event_flag_mcconnell function to get the valid points
  valid_points <- event_flag_mcconnell( # nolint: object_usage_linter.
    x,
    max_speed = max_speed,
    check_first_last = check_first_last
  ) # nolint: object_usage_linter.

  apply_flag_action(x, valid_points, flag_action)
}

#' Act on the events flagged by a cleaning algorithm
#'
#' Shared by the `tt_clean_*()` functions to act on the events that are not
#' valid.
#'
#' @param x A `move2` object.
#' @param valid A logical vector with one value per event of `x`, `FALSE` for
#'   the events to act on.
#' @param flag_action One of "remove", "null", or "interpolate", to either
#'   remove the flagged events, keep their time stamp but set their location to
#'   NULL, or replace their location with a linearly interpolated location from
#'   the valid events.
#' @returns The `move2` object `x`, with the flagged events acted on.
#' @keywords internal
#' @noRd
apply_flag_action <- function(x, valid, flag_action) {
  # flag_action has been validated with match.arg() by the caller
  if (flag_action == "remove") {
    return(x[valid, ])
  }
  # "null" and "interpolate" keep every event (and so its time stamp and
  # attributes), and empty the location of the flagged events
  sf::st_geometry(x)[!valid] <- sf::st_point()
  # mt_interpolate() fills in every event with an empty location, so events
  # that had no location before cleaning are interpolated too
  if (flag_action == "interpolate") {
    x <- move2::mt_interpolate(x)
  }
  x
}
