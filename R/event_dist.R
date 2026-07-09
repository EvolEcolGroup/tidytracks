#' Measure the distance between pairs of consecutive events within each track
#'
#' This function returns the distance of each segment between events for each
#' track. In order to return a vector with the same number of rows as the event
#' table, the distance of the last event is set to NA.
#'
#' For unprojected longitudes and latitudes, the distance is computed as the
#' geodesic distance (via the `geodist` package); for projected coordinates, the
#' Euclidean distance is used.
#'
#' @param x A move2 object.
#' @param units Optional, the units to use for the distance. The default is "m".
#'' Other distance units supported by the `units` package can also be supplied.
#' @returns A vector of distances of the same length as the number of events in
#' `x`, with the last value set to NA for each track.
#' @export
#' @examples
#' event_distance(example_tt)
#' event_distance(example_tt, units = as_units("km"))
#'
event_distance <- function(x, units = as_units("m")) {
  # check that x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # check that units is a units object
  if (!inherits(units, "units")) {
    stop("units must be a units object: e.g. as_units('km')")
  }

  # give error if we don't have a crs
  if (is.null(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }

  coords <- sf::st_coordinates(x)
  track_id <- move2::mt_track_id(x)

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

  # get distance units from CRS
  dist_units <- units(sf::st_distance(x$geometry[1:2]))

  # assign units
  dist <- units::as_units(dist, dist_units)

  # convert to requested units
  if (!is.null(units)) {
    dist <- units::set_units(
      units::ud_convert(
        x = unclass(dist),
        from = units(dist),
        to = units::deparse_unit(units)
      ),
      units,
      mode = "standard"
    )
  }

  return(dist)
}
