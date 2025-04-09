#' Return the speed of each segment between events
#'
#' This function returns the speed of each segment between events for each
#' track. In order to return a vector with the same number of rows as the
#' event table, the speed of the last event is set to NA. The speed is calculated
#' as the distance between events divided by the time between events.
#'
#' @param x A move2 object
#' @param units Optiona, the units to use for the speed. The default is "m/s". Other
#' @returns a vector of speeds of the same lenght as the number of events in `x`
#' @export

event_speed <- move2::mt_speed
