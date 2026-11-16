#' Filter the tracks based on variables from the metadata
#'
#' This function is based heavily on `move2::filter_track_data()`, but it is
#' updated so that it still works if the track metadata has a  geometry column.
#' It allows you to filter tracks based on any variables in the metadata table,
#' including the track ID column (which you can specify using the track ID
#' column name, or the shorthand `.track_id`).
#'
#' Locations in the metadata (e.g. of a colony), stored as `sfc` columns (see
#' [sf_point_col()]) or as the geometry of an `sf` table of metadata, can be
#' used in the conditions, e.g. with the spatial predicates of `sf` (such as
#' [sf::st_intersects()] or [sf::st_is_within_distance()]). The events keep
#' their own geometry.
#'
#' @param .data A move2 object
#' @param ... Selection criteria based on the variables of the track metadata
#'   (logical conditions, as in [dplyr::filter()]); to select tracks by their
#'   ids, use `.track_id`
#' @param .track_id A vector of the ids of the tracks to select
#' @returns A move2 object with only the selected tracks
#' @export
#' @examples
#' subset_tt <- example_tt %>% filter_by_meta(sex == "female")
#' show_meta(subset_tt)
#'
#' # store the locations of the nests as an sfc column of the metadata
#' nests_tt <- example_tt
#' show_meta(nests_tt)$nest <- sf_point_col(
#'   x = show_meta(nests_tt)$nest_lon,
#'   y = show_meta(nests_tt)$nest_lat,
#'   crs = 4326
#' )
#' # keep the tracks with a nest within 200 km of a point
#' centre <- sf_point_col(x = 0, y = 0, crs = 4326)
#' nests_tt %>%
#'   filter_by_meta(sf::st_is_within_distance(
#'     nest, centre,
#'     dist = 200000, sparse = FALSE
#'   )[, 1]) %>%
#'   show_meta()
filter_by_meta <- function(.data, ..., .track_id = NULL) {
  # at this point, .data is a move2 object with track_id_field 'trip_id'
  # metadata table may or may not have a geometry column
  # First, we apply the filtering to the METADATA
  new_id_data <- show_meta(.data) |> dplyr::filter(...)
  # Next, we apply any filtering on the track_id_column that was specified
  # (the ids are injected, so that they cannot be masked by a column of the
  # metadata with the same name)
  if (!is.null(.track_id)) {
    track_ids_to_keep <- .track_id
    new_id_data <- new_id_data |>
      dplyr::filter(
        !!rlang::sym(colname_track_id(.data)) %in% !!track_ids_to_keep
      )
  }
  # Get a vector of the track IDs that we're keeping.
  new_tracks <- new_id_data |>
    # in case there is geometry in metadata, drop it here
    sf::st_drop_geometry() |>
    # track_id_column is "trip_id"
    dplyr::select(!!rlang::sym(colname_track_id(.data))) |>
    dplyr::pull()
  # Now we apply the filtering to the EVENTS DATA
  # Keep the events whose track ID is in the vector of track IDs we want to
  # keep (the ids are injected, so that they cannot be masked by a column of
  # the events table; the condition is evaluated on the track id column, rather
  # than injected as a logical vector over all events, so that it also works
  # within the groups of a grouped object)
  .data <- .data |>
    dplyr::filter(
      !!rlang::sym(colname_track_id(.data)) %in% !!new_tracks
    )
  # Finally, reset the metadata of the newly filtered events table
  .data <- move2::mt_set_track_data(.data, new_id_data)
  return(.data)
}
