#' Return the time of each event
#'
#' This is a helper function to access the time of each event in a move2 object;
#' it returns content of the column designated "time_column" in the move2
#' object.
#' @param x A move2 object
#' @returns a vector of times of the same length as the number of events in `x`
#' @export
#' @examples
#' event_time(example_tt)
#'

event_time <- move2::mt_time
