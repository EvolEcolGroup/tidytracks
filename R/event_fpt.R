#' Compute the first passage time of each event
#'
#' This function returns, for each event, its first passage time (FPT): the time
#' that the animal takes to cross a circle of the given radius centred on the
#' location of the event, i.e. the time since it entered the circle plus the
#' time until it leaves it (Fauchald & Tveraa 2003). The time at which the track
#' crosses the circle is found by linear interpolation between the last location
#' inside the circle and the first one outside it, as in
#' `adehabitatLT::fpt()`.
#'
#' Events get `NA` if the track does not leave the circle both before and after
#' them, so larger circles leave fewer events with an FPT. Events without a
#' location get `NA`, and the track is taken to run straight between the
#' locations on either side of them. So do the events of the dummy trips of the
#' events at the centre, labelled "trip_na" (see [tt_split_trips()]), as the
#' animal is not continuously tracked between them.
#'
#' The FPT of an event only depends on the events of its own track. After
#' [tt_split_trips()] each trip is a track, so the FPT does not run across
#' trips, and therefore does not include the time at the centre between them.
#'
#' `x` must be in a projected coordinate reference system (see
#' [sf::st_transform()]), as the circles are computed on the plane, and be
#' ordered by time within each track (see [tt_order_time()]).
#'
#' @references Fauchald, P. & Tveraa, T. (2003) Using first-passage time in the
#'   analysis of area-restricted search and habitat selection. Ecology, 84,
#'   282-288.
#' @param x A move2 object.
#' @param radius The radius of the circle, as a `units` object, e.g.
#'   `as_units(10, "km")`.
#' @param units The units of the returned times, as a `units` object. The
#'   default is hours (`as_units("h")`).
#' @returns A `units` vector with the FPT of each event of `x`.
#' @seealso [track_fpt_profile()] to compute how the variance of the FPT changes
#'   with the radius, and [track_suggest_ars_scale()] to find the scale of
#'   area-restricted search from it.
#' @export
#' @examples
#' x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
#' event_fpt(x, radius = as_units(100, "km"))
event_fpt <- function(x, radius, units = as_units("h")) {
  check_fpt_x(x)
  if (!inherits(units, "units")) {
    stop("units must be a units object: e.g. as_units('h')")
  }
  radii <- fpt_radii_in_crs_units(radius, x, "radius")
  if (length(radii) != 1) {
    stop("radius must be a single value")
  }
  fpt <- units::as_units(fpt_matrix(x, radii)[, 1], "s")
  units::set_units(fpt, units, mode = "standard")
}

#' Check the object of the FPT functions
#'
#' @param x The object to check.
#' @returns `NULL`, invisibly; gives an error if `x` is not a move2 object in a
#'   projected CRS, ordered by time within each track.
#' @keywords internal
#' @noRd
check_fpt_x <- function(x) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  if (isTRUE(sf::st_is_longlat(x))) {
    stop(
      "x must be in a projected coordinate reference system (CRS), as the ",
      "first passage time is computed on the plane; use sf::st_transform()"
    )
  }
  if (nrow(x) == 0) {
    stop("x must have events")
  }
  check_time_ordered(x) # nolint: object_usage_linter.
  invisible(NULL)
}

#' Convert radii to the units of the coordinates of an object
#'
#' @param radii The radii, as a `units` object.
#' @param x A move2 object in a projected CRS.
#' @param arg The name of the argument, for the error messages.
#' @returns A numeric vector with the radii in the units of the CRS of `x`,
#'   sorted and without duplicates.
#' @keywords internal
#' @noRd
fpt_radii_in_crs_units <- function(radii, x, arg = "radii") {
  if (!inherits(radii, "units")) {
    stop(arg, " must be a units object: e.g. as_units(10, 'km')")
  }
  converted <- tryCatch(
    units::set_units(radii, sf::st_crs(x)$ud_unit, mode = "standard"),
    error = function(e) {
      stop(arg, " must be a distance: e.g. as_units(10, 'km')", call. = FALSE)
    }
  )
  converted <- as.numeric(converted)
  if (length(converted) == 0 || any(!is.finite(converted) | converted <= 0)) {
    stop(arg, " must contain finite, positive values")
  }
  sort(unique(converted))
}

#' Whether the tracks of the events are dummy trips of events at the centre
#'
#' @param track_id The track ids of the events, as characters.
#' @returns A logical vector.
#' @keywords internal
#' @noRd
is_trip_na <- function(track_id) {
  grepl("_trip_na$", track_id)
}

#' First passage time of all the events, for several radii
#'
#' @param x A move2 object, checked with `check_fpt_x()`.
#' @param radii Numeric vector of radii in the units of the CRS of `x`, in
#'   increasing order.
#' @returns A matrix with one row per event and one column per radius, with the
#'   FPT in seconds.
#' @keywords internal
#' @noRd
fpt_matrix <- function(x, radii) {
  xy <- sf::st_coordinates(x)
  time <- as.numeric(as.POSIXct(event_time(x)))
  ids <- as.character(event_track_id(x))
  res <- matrix(NA_real_, nrow(xy), length(radii))
  usable <- stats::complete.cases(xy) & !is_trip_na(ids)
  # the events of each track, which are stored together and in time order
  for (rows in split(which(usable), ids[usable])) {
    res[rows, ] <- fpt_cpp( # nolint: object_usage_linter.
      xy[rows, 1],
      xy[rows, 2],
      time[rows],
      radii
    )
  }
  res
}
