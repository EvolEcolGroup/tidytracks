#' Return the speed of each segment between events
#'
#' This function returns the speed of each segment between events for each
#' track. In order to return a vector with the same number of rows as the event
#' table, the speed of the last event is set to NA. The speed is calculated as
#' the distance between events divided by the time between events.
#'
#' The speeds are computed between consecutive events, so the events of each
#' track must be stored together and ordered by time; otherwise, an error is
#' given (use [tt_order_time()] to order them).
#'
#' For unprojected longitudes and latitudes, the distance is computed as the
#' geodesic distance (via the `geodist` package); for projected coordinates, the
#' Euclidean distance is used.
#'
#' @param x A move2 object
#' @param units The units to use for speed, as a `units` object. The default is
#'   metres per minute (`as_units("m/min")`); other speed units supported by
#'   the `units` package can also be supplied (e.g. `as_units("m/s")`).
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
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }

  # the speeds are those between consecutive events, which must therefore be
  # ordered by time within each track (an object without events is ordered,
  # but move2::mt_is_time_ordered() gives an error for it)
  if (nrow(x) > 0) {
    check_time_ordered(x) # nolint: object_usage_linter.
  }

  track_id <- move2::mt_track_id(x)
  time <- move2::mt_time(x)

  n <- length(track_id)

  # segment belongs to same track (subset to n values, as there is no last
  # event to pad if there are no events)
  same_track <- c(track_id[-1] == track_id[-n], FALSE)[seq_len(n)]

  # distances for all consecutive pairs
  dist <- event_distance(x)

  dt <- as_units(c(diff(time), NA_real_)[seq_len(n)])

  dt[!same_track] <- NA_real_

  speed <- dist / dt

  # convert the speed into the requested units
  speed <- units::set_units(
    # units::ud_convert() converts the values one at a time, which is slow
    # for many events; speed units only differ by a scale factor, so the
    # values are multiplied by the conversion factor instead
    as.numeric(speed) *
      units::ud_convert(
        x = 1,
        from = units(speed),
        to = units::deparse_unit(units)
      ),
    units,
    mode = "standard"
  )

  return(speed)
}
