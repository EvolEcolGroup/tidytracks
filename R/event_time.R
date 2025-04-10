#' Return the time of each event
#'
#' This is a helper function to
#' access the time of each event in a move2 object; it accesses the
#' designated "time_column" in the move2 object.
#' @param x A move2 object
#' @returns a vector of distances of the same length as the number of events in `x`
#' @export

event_time <- move2::mt_time
