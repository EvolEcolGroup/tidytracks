#' Filter the tracks based on variables from the metadata
#' 
#' This function is based heavily on `move2::filter_track_data()`, but it is 
#' updated so that it still works if the track metadata has a  geometry column. 
#' It allows you to filter tracks based on any variables in the metadata table,
#' including the track ID column (which you can specify using the track ID 
#' column name, or the shorthand `.track_id`).
#'
#' @param .data A move2 object
#' @param ... The identifiers of one or more tracks to select or selection
#' criteria based on track metadata
#' @param .track_id A vector of the ids of the tracks to select
#' @returns A move2 object with only the selected tracks
#' @export

filter_by_meta <- function(.data, ..., .track_id = NULL) {
  # at this point, .data is a move2 object with track_id_field 'trip_id'
  # metadata table may or may not have a geometry column
  # First, we apply the filtering to the METADATA 
  new_id_data <- show_meta(.data) |> dplyr::filter(...)
  # Next, we apply any filtering on the track_id_column that was specified
  if (!is.null(.track_id)) {
    track_ids_to_keep <- .track_id
    new_id_data <- new_id_data |> dplyr::filter(!!rlang::sym(attr(.data, "track_id_column")) %in% track_ids_to_keep)
  }
  # Get a vector of the track IDs that we're keeping.
  new_tracks <- new_id_data |>
    sf::st_drop_geometry() |> # in case there is geometry in metadata, drop it here
    dplyr::select(!!rlang::sym(attr(.data, "track_id_column"))) |> # track_id_column is "trip_id"
    dplyr::pull()
  # Now we apply the filtering to the EVENTS DATA
  # Get track IDs of every line in the events table
  ids <- event_track_id(.data)
  # Filter events table to where track ID is in the vector of track IDs we want to keep
  .data <- .data |> dplyr::filter(ids %in% new_tracks)
  # Finally, reset the metadata of the newly filtered events table
  .data <- move2::mt_set_track_data(.data, new_id_data)
  return(.data)
}
