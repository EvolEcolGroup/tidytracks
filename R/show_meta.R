#' Show or set the track metadata of a `move2` object
#'
#' The track metadata is stored as a data frame within the `move2` object. This
#' function allows you to view or modify this metadata. When retrieving the
#' metadata, it returns a tibble containing the metadata for each track. When
#' setting the metadata, you can provide a new data frame with the updated
#' metadata, or modify or remove specific columns, as you would normally do with
#' a data.frame/tibble. If providing a new metadata table, make sure that
#' the number of rows matches the number of tracks in the `move2` object, and
#' that the track IDs correspond to those in the `move2` object.
#'
#' Locations in the metadata (e.g. of a colony) are best stored as `sfc`
#' columns of a plain table (see [sf_point_col()]). An `sf` table of metadata
#' is stored as a plain table, with its geometry kept as an `sfc` column, as
#' move2 cannot join an `sf` table to the events (e.g. in [as_event_column()]).
#' A metadata column with the same name as the geometry column of the events
#' (e.g. `geometry`, the default name of the geometry of an `sf` table) would
#' replace it when joined to the events, so it is renamed with a `.meta`
#' suffix (e.g. `geometry.meta`), with a message.
#' @param x A move2 object
#' @return The metadata table from the input `move2` object (nothing is
#' returned if using the setter function).
#' @export
#' @examples
#' show_meta(example_tt)
#' show_meta(example_tt)$age <- c(2, 3, 2)
#' show_meta(example_tt)
show_meta <- move2::mt_track_data

#' @rdname show_meta
#' @param value A data frame with metadata to set for the `move2` object
#' @export
"show_meta<-" <- function(x, value) {
  # move2::mt_set_track_data() checks that the metadata has all the tracks,
  # and no others, but not that it has a single row per track
  track_ids <- value[[move2::mt_track_id_column(x)]]
  duplicated_ids <- unique(track_ids[duplicated(track_ids)])
  if (length(duplicated_ids) > 0) {
    stop(
      "The metadata has more than one row for track(s) ",
      paste(duplicated_ids, collapse = ", "),
      "; each track must have a single row.",
      call. = FALSE
    )
  }
  value <- plain_meta(value, attr(x, "sf_column"))
  x <- move2::mt_set_track_data(x, value)
  return(x)
}

#' Turn metadata into a plain table that can be joined to the events
#'
#' move2 joins the metadata to the events with dplyr (e.g. in
#' `move2::mt_as_event_attribute()` and `move2::mt_track_lines()`), which sf
#' does not allow for an `sf` table, so an `sf` table of metadata is turned
#' into a plain table, with its geometry kept as an `sfc` column. A metadata
#' column with the name of the geometry column of the events would replace it
#' (as `geometry.x` and `geometry.y`) when joined to the events, so it is
#' renamed with a `.meta` suffix (as tt_read_data() does for columns in both
#' tables), with a message.
#'
#' @param meta The metadata of a `move2` object.
#' @param event_geometry The name of the geometry column of the events.
#' @returns `meta`, as a plain table without a column named `event_geometry`.
#' @keywords internal
#' @noRd
plain_meta <- function(meta, event_geometry) {
  if (inherits(meta, "sf")) {
    cols <- names(meta)
    geometry_col <- attr(meta, "sf_column")
    geometry <- sf::st_geometry(meta)
    meta <- sf::st_drop_geometry(meta)
    meta[[geometry_col]] <- geometry
    # keep the geometry column where it was
    meta <- meta[cols]
  }
  if (event_geometry %in% names(meta)) {
    new_name <- paste0(event_geometry, ".meta")
    message(
      "The metadata column '", event_geometry, "' has the same name as the ",
      "geometry column of the events, so it has been renamed '", new_name, "'"
    )
    names(meta)[names(meta) == event_geometry] <- new_name
  }
  meta
}
