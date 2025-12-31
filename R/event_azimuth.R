#' Measure the azimuth between two events
#'
#' This function measures the azimuth between two events. It returns a vector of
#' azimuths of the same length as the number of events in `x`, with the azimuth
#' for the last event of each track padded with an NA.
#' @param x A move2 object
#' @param units Optional, the units to use for the azimuth. The default is "m".
#' @returns a vector of azimuths of the same length as the number of events in
#'   `x`, with the last value set to NA for each track.
#' @export

event_azimuth <- move2::mt_azimuth
