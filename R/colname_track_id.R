#' Return the name of the track id column
#'
#' This is a helper function to get the name of the column of the events (and
#' of the metadata) that holds the track id of each event, i.e. the column
#' designated "track_id_column" in the move2 object (e.g. `trip_id` after
#' [tt_split_trips()]). To get the track id of each event, use
#' [event_track_id()]; to change the track id column, use
#' [move2::mt_set_track_id_column()].
#' @param x A move2 object
#' @returns The name of the track id column of `x`, as a character string
#' @seealso [colname_time()] for the name of the time column
#' @export
#' @examples
#' colname_track_id(example_tt)
#'
colname_track_id <- move2::mt_track_id_column
