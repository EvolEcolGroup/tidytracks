#' Return the speed of each segment between events
#'
#' This function returns the speed of each segment between events for each
#' track. In order to return a vector with the same number of rows as the event
#' table, the speed of the last event is set to NA. The speed is calculated as
#' the distance between events divided by the time between events.
#' 
#' For unprojected longitudes and latitudes, the distance is computed as the
#' geodesic distance (via the `geodist` package); for projected coordinates, the
#' Euclidean distance is used.
#'
#' @param x A move2 object
#' @param units Optional, the units to use for the speed. The default is "m/min".
#'   Other speed units supported by the `units` package can also be supplied.
#' @returns a vector of speeds of the same length as the number of events in
#' `x`, with the last value set to NA for each track.
#' @export
#' @examples
#' event_speed(example_tt)
#' event_speed(example_tt, units = as_units("m/s"))
#' 

event_speed <- function(x, units = as_units("m/min")) {
  
  # check that x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  
  # check that units is a units object
  if (!inherits(units, "units")) {
    stop("units must be a units object: e.g. as_units('m/s')")
  }
  
  # give error if we don't have a crs
  if (is.null(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  
  coords <- sf::st_coordinates(x)
  track_id <- move2::mt_track_id(x)
  time <- move2::mt_time(x)
  
  crs <- sf::st_crs(x)
  longlat <- sf::st_is_longlat(x)
  
  n <- nrow(coords)
  
  # segment belongs to same track
  same_track <- c(track_id[-1] == track_id[-n], FALSE)
  
  # distances for all consecutive pairs
  dist <- c(
    dist_fast(
      coords[-n, 1],
      coords[-n, 2],
      coords[-1, 1],
      coords[-1, 2],
      longlat = longlat
    ),
    NA_real_
  )
  
  # invalidate track boundaries
  dist[!same_track] <- NA_real_
  
  # get the units of the distance
  dist_units <- units(sf::st_distance(x$geometry[1:2]))
  # set the units for dist
  dist <- units::as_units(dist, dist_units)

  dt <- as_units(c(diff(time), NA_real_))
  
  dt[!same_track] <- NA_real_
  
  speed <- dist / dt
  
  if (!is.null(units)) {
    # convert the speed into the reference units of the projection
    
    speed <- units::set_units(
      units::ud_convert(
        x = unclass(speed),
        from = units(speed),
        to = units::deparse_unit(units)
      ),
      units,
      mode = "standard"
    )
    
  }
  
  return(speed)
}
