#' Clean a `move2` object using McConnell's algorithm
#'
#' This function cleans a `move2` object using McConnell's algorithm. It removes
#' outliers based on the distance between consecutive points and the time
#' interval between them (more explanation; give reference TODO). This function
#' returns a clean `move2` object; to generate a column that flags events to
#' remove but does not remove them, use `event_flag_mcconnell()`.
#'
#' @param x A move2 object
#' @param max_speed speed, provided as a `units` object (e.g.
#' units::as_units(50, 'm/s').
#' @param flag_action One of "remove", "null", or "interpolate", to either
#' remove the points flagged by the algorithm, keep the time stamp but set
#' location to NULL, or replace the location with a linearly interpolated
#' location from the events that were not filtered out.
#' @return A clean `move2` object with events removed
#' @export

tt_clean_mcconnell <- function(x, max_speed = NULL,
                               flag_action = c("remove", "interpolate", "null")) {
  # checking for appropriate x and max_speed is done by event_flag_mcconnell
  flag_action <- match.arg(flag_action)

  # Call the event_flag_mcconnell function to get the valid points
  valid_points <- event_flag_mcconnell(x, max_speed)

  if (flag_action=="remove"){
    x <- x[valid_points,]
  } else if (flag_action=="null"){
    sf::st_geometry(x)[!valid_points] <- sf::st_point()
  } else if (flag_action == "interpolate"){
    sf::st_geometry(x)[!valid_points] <- sf::st_point()
    x <- move2::mt_interpolate(x)
  }
  return(x)
}
