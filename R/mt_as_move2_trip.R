#' Method to convert `trip` objects to `move2` objects
#'
#' Convert `trip` objects to `move2` objects.
#' @param x A trip object
#' @param ... Additional arguments (currently ignored)
#' @return A move2 object
#' @export
#' @examplesIf rlang::is_installed("trip")
#' mt_as_move2(trip::walrus818)
mt_as_move2.trip <- function(x, ...) {
  if (!requireNamespace("trip", quietly = TRUE)) {
    stop(
      "to use this function, first install package 'trip' with\n",
      "install.packages('trip')"
    )
  }
  # check if x is a trip object
  if (!inherits(x, "trip")) {
    stop("x must be a trip object")
  }
  # names of the time and track id columns
  tor_names <- trip::getTORnames(x)

  # convert to spdf
  x_stdf <- methods::as(x, "SpatialPointsDataFrame")
  # now cast as sf
  x_sf <- sf::st_as_sf(x_stdf)
  # and finally as move2 object
  return(move2::mt_as_move2(
    x_sf,
    time_column = tor_names[1],
    track_id_column = tor_names[2]
  ))
}
