#' Measure the distance between two events
#'
#' This function measures the distance between two events. It returns a vector of
#' distances of the same length as the number of events in `x`, with the
#' distance for the last event of each track padded with an NA. For
#' unprojected longitudes and latitudes, the distance is
#' computed as the geodesic distance, which for projected coordinates,
#' the Euclidean distance is used.
#' @param x A move2 object
#' @param units Optional, the units to use for the distance. The default is "m".
#' @returns a vector of distances of the same length as the number of events in `x`
#' @export

event_distance <- move2::mt_distance
