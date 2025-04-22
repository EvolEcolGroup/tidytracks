#' Compute summary statistics for each track
#'
#' This function provides a set of summary statistics for each track. It is
#' unusual in returning a tibble of multiple variables rather than a single
#' vector. The summary statistics include the duration of the track, the
#' cumulative distance, the maximum distance from the start (or from a
#' prescribed central place), the maximum and minimum latitude and longitude.
#'
#' @param x A `move2` object
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track.
#' @export

track_summary_stats <- function(x, units_duration = units::as_units(1, "days")) {
  warning("this function is still incomplete")
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  tot_duration <- track_duration(x, units = units_duration)
  # get distance units
  dist_units <- units(sf::st_distance(x$geometry[1:2]) /
                       units::as_units(60, "h")) # we measure time in hours
  # get coordinates
  coords <- sf::st_coordinates(x)
  is_longlat <- sf::st_is_longlat(x)

  # TODO write a cum_distance function that works on coords



  sum_stats <- tibble(duration = tot_duration,
                      #cum_distance = event_distance(x),
                      #max_dist_from_start = event_distance(x, from = coords[1, ]),
                      max_latitude = max(coords[, 2], na.rm = TRUE),
                      min_latitude = min(coords[, 2], na.rm = TRUE),
                      max_longitude = max(coords[, 1], na.rm = TRUE),
                      min_longitude = min(coords[, 1], na.rm = TRUE)
  )

  return(sum_stats)
}
