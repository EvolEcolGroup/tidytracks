#' Return the track id of each event
#'
#' This is a helper function to access the track id of each event in a move2
#' object; it returns content of the column designated "track_id_column" in the
#' move2 object.
#' @param x A move2 object
#' @returns a vector of track IDs of the same length as the number of events in
#'   `x`
#' @export
#' @examples
#' event_track_id(example_tt)
#' 
event_track_id <- move2::mt_track_id
