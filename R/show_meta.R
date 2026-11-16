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
#'
#' The only column that the events and the metadata should share is the track
#' id. When setting the metadata, a column that is also in the events is
#' removed from the events if it has the same values (for the events of each
#' track), as it is information about the tracks; if the events are grouped by
#' it, it is removed from the metadata instead. A column with different values
#' (e.g. that varies within tracks) is kept in both tables, with the version in
#' the metadata renamed with a `.meta` suffix, with a warning. (To make
#' another column the track id with [move2::mt_set_track_id_column()], which
#' needs it in both tables, add it to the events after setting the metadata.)
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
  track_ids <- value[[colname_track_id(x)]]
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
  # the only column in both the events and the metadata should be the track
  # id: remove (or rename) the columns of the new metadata that are also in
  # the events
  x <- drop_duplicated_columns(x)
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

#' Make the metadata of a move2 object a plain table
#'
#' For the functions that join the metadata to the events with move2, as the
#' metadata may have been set without `show_meta<-` (e.g. with
#' `move2::mt_set_track_data()` or `move2::mt_as_move2()`); see `plain_meta()`.
#'
#' @param x A `move2` object.
#' @returns `x`, with its metadata as a plain table.
#' @keywords internal
#' @noRd
with_plain_meta <- function(x) {
  meta <- move2::mt_track_data(x)
  plain <- plain_meta(meta, attr(x, "sf_column"))
  if (identical(plain, meta)) {
    return(x)
  }
  move2::mt_set_track_data(x, plain)
}

#' The row of the metadata of each event
#'
#' @param x A `move2` object.
#' @param meta The metadata of `x`.
#' @returns An integer vector with, for each event of `x`, the row of `meta`
#'   of its track.
#' @keywords internal
#' @noRd
event_meta_rows <- function(x, meta = show_meta(x)) {
  event_ids <- move2::mt_track_id(x)
  meta_ids <- meta[[colname_track_id(x)]]
  if (is.factor(event_ids)) {
    # use the codes of the factor of the track ids, which is much faster for
    # many events
    match(levels(event_ids), meta_ids)[as.integer(event_ids)]
  } else {
    match(event_ids, meta_ids)
  }
}

#' Whether two columns have the same values
#'
#' The columns are compared (including their NA patterns) after casting them
#' to a common type, as the same values can be stored with different types
#' (e.g. integer and double, or character and factor); columns with
#' incompatible types (e.g. character and numeric) differ.
#'
#' @param x,y Two vectors of the same length.
#' @returns `TRUE` or `FALSE`.
#' @keywords internal
#' @noRd
same_column_values <- function(x, y) {
  tryCatch(
    all(vctrs::vec_equal(x, y, na_equal = TRUE)),
    vctrs_error_incompatible_type = function(e) FALSE
  )
}

#' Check the columns that are both in the events and in the metadata
#'
#' The only column that the events and the metadata of a `move2` object should
#' share is the track id. When columns are moved from one table to the other
#' (e.g. by [as_event_column()]), a column that is already in both tables with
#' the same values (for the events of each track) is not moved again, as it
#' would be duplicated; with different values, it gives an error.
#'
#' @param x A `move2` object.
#' @param cols The names of the columns to check.
#' @returns The columns of `cols` (other than the track id) that are in both
#'   tables, with the same values; an error if any of them has different values.
#' @keywords internal
#' @noRd
check_same_in_both <- function(x, cols) {
  meta <- show_meta(x)
  cols <- intersect(intersect(cols, names(x)), names(meta))
  cols <- setdiff(cols, colname_track_id(x))
  if (length(cols) == 0) {
    return(character(0))
  }
  meta_rows <- event_meta_rows(x, meta)
  same <- vapply(
    cols,
    function(col) same_column_values(x[[col]], meta[[col]][meta_rows]),
    logical(1)
  )
  if (!all(same)) {
    stop(
      "Column(s) ", paste0("'", cols[!same], "'", collapse = ", "),
      " are both in the events and in the metadata, with values that differ; ",
      "rename one of them first",
      call. = FALSE
    )
  }
  cols
}

#' Remove the columns that are both in the events and in the metadata
#'
#' The only column that the events and the metadata of a `move2` object should
#' share is the track id. A column in both tables with the same values (for
#' the events of each track), i.e. information about the tracks, is removed
#' from the events and kept in the metadata, unless the events are grouped by
#' it, in which case it is removed from the metadata. A column with different
#' values (e.g. that varies within tracks), or with the name of the time or
#' geometry column of the events, is kept in both tables, with the version in
#' the metadata renamed with a `.meta` suffix, with a warning.
#'
#' @param x A `move2` object.
#' @returns `x`, without columns in both tables.
#' @keywords internal
#' @noRd
drop_duplicated_columns <- function(x) {
  meta <- show_meta(x)
  shared <- setdiff(
    intersect(names(x), names(meta)),
    colname_track_id(x)
  )
  if (length(shared) == 0) {
    return(x)
  }
  meta_rows <- event_meta_rows(x, meta)
  # the time and the geometry of the events stay in the events
  in_events_only <- c(colname_time(x), attr(x, "sf_column"))
  same <- vapply(
    shared,
    function(col) {
      !col %in% in_events_only &&
        same_column_values(x[[col]], meta[[col]][meta_rows])
    },
    logical(1)
  )
  # information about the tracks is kept in the metadata only, unless the
  # events are grouped by it (dplyr::select() would keep it in the events), in
  # which case it is kept in the events only
  same_cols <- shared[same]
  in_groups <- same_cols %in% dplyr::group_vars(x)
  if (any(!in_groups)) {
    x <- dplyr::select(x, -dplyr::all_of(same_cols[!in_groups]))
  }
  meta <- meta[setdiff(names(meta), same_cols[in_groups])]
  # columns with different values are kept in both tables, renaming the
  # version in the metadata
  if (any(!same)) {
    renamed <- shared[!same]
    new_names <- paste0(renamed, ".meta")
    warning(
      "Column(s) ", paste0("'", renamed, "'", collapse = ", "),
      " are both in the events and in the metadata, with values that ",
      "differ; the version(s) in the metadata are renamed ",
      paste0("'", new_names, "'", collapse = ", "),
      call. = FALSE
    )
    names(meta)[match(renamed, names(meta))] <- new_names
  }
  if (any(in_groups) || any(!same)) {
    x <- move2::mt_set_track_data(x, meta)
  }
  x
}
