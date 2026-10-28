#' Measure the azimuth between two events
#'
#' This function measures the azimuth between two events. It returns a vector of
#' azimuths of the same length as the number of events in `x`, with the azimuth
#' for the last event of each track padded with an NA.
#' @param x A move2 object
#' @param units Optional, the units to use for the azimuth (e.g., "degrees" or
#'   "radians"). The default is "degrees".
#' @returns a vector of azimuths of the same length as the number of events in
#'   `x`, with the last value set to NA for each track.
#' @export
#' @examples
#' event_azimuth(example_tt)
event_azimuth <- function(x, units = "degrees") {
  # move2::mt_azimuth() returns radians if no units are given
  move2::mt_azimuth(x, units = units)
}
