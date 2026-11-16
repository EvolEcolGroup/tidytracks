#' Move one (or more) variable(s) from the metadata to the event data as a new
#' column(s).
#'
#' This function moves one or more columns from the metadata of a `move2` object
#' to the event data, adding them as new columns. This is useful when you want
#' to include metadata information in the event-level analysis.
#'
#' A column that is already in the events, with the same values as in the
#' metadata (for the events of each track), is not duplicated: it is only
#' removed from the metadata (unless `.keep = TRUE`); with different values, it
#' gives an error, as the only column in both tables should be the track id.
#' For the same reason, `.keep = TRUE` is deprecated.
#'
#' An `sf` table of metadata is turned into a plain table first, with its
#' geometry kept as an `sfc` column, which is renamed if it has the name of
#' the geometry column of the events (see [show_meta()]).
#' @param x A `move2` object
#' @param ... One or more unquoted column names from the metadata to move to the
#'   event data; it is possible to use tidyselect helpers to select multiple
#'   columns.
#' @param .keep Deprecated. `TRUE` keeps the columns in the metadata too,
#'   which leaves them in both tables (and [`show_meta<-`][show_meta()] removes
#'   them from the events the next time that the metadata is set). The default,
#'   `FALSE`, removes them from the metadata.
#' @returns A `move2` object with the specified metadata columns added to the
#'   event data.
#' @export
#' @examples
#' example_tt2 <- as_event_column(example_tt, sex)
#' example_tt2 # now showing sex in the events table
as_event_column <- function(x, ..., .keep = FALSE) {
  # the only column in both tables should be the track id
  if (isTRUE(.keep)) {
    lifecycle::deprecate_soft(
      "0.3.0", "as_event_column(.keep = 'must be FALSE')",
      details = paste(
        "The only column in both the events and the metadata should be the",
        "track id; move the columns back with `as_meta_column()` if needed."
      )
    )
  }
  # move2 cannot join an sf table of metadata to the events
  x <- with_plain_meta(x) # nolint: object_usage_linter.
  # the columns of the metadata to move
  cols <- names(dplyr::select(show_meta(x), ...))
  # columns that are already in the events, with the same values, are not
  # joined again (which would duplicate them, as .x and .y), but only removed
  # from the metadata (unless .keep is TRUE); with different values, they
  # give an error
  in_events <- check_same_in_both(x, cols) # nolint: object_usage_linter.
  if (length(in_events) > 0) {
    if (!.keep) {
      meta <- show_meta(x)
      x <- move2::mt_set_track_data(x, meta[setdiff(names(meta), in_events)])
    }
    cols <- setdiff(cols, in_events)
    if (length(cols) == 0) {
      return(x)
    }
  }
  move2::mt_as_event_attribute(x, dplyr::all_of(cols), .keep = .keep)
}
