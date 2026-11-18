#' Return the name of the time column
#'
#' This is a helper function to get the name of the column of the events that
#' holds the time of each event, i.e. the column designated "time_column" in
#' the move2 object. To get the time of each event, use [event_time()]; to
#' change the time column, use [move2::mt_set_time_column()].
#' @param x A move2 object
#' @returns The name of the time column of `x`, as a character string
#' @seealso [colname_track_id()] for the name of the track id column
#' @export
#' @examples
#' colname_time(example_tt)
#'
colname_time <- move2::mt_time_column
