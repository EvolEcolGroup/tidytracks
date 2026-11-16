#' Move one (or more) variable(s) from the event data to the metadata as a new
#' column(s).
#'
#' This function moves one or more columns from the event data of a `move2`
#' object to the metadata, adding them as new columns. This is useful when you
#' want to include event-level information in the metadata. Note that all events
#' for a given track must have the same value for the variable being moved to
#' metadata.
#'
#' A column that is already in the metadata, with the same values as in the
#' events (for the events of each track), is not duplicated: it is only removed
#' from the events (unless `.keep = TRUE`); with different values, it gives an
#' error, as the only column in both tables should be the track id. For the
#' same reason, `.keep = TRUE` is deprecated.
#' @param x A `move2` object
#' @param ... One or more unquoted column names from the event data to move to
#'  the metadata; it is possible to use tidyselect helpers to select multiple
#'  columns.
#' @param .keep Deprecated. `TRUE` keeps the columns in the events too, which
#'  leaves them in both tables (and [`show_meta<-`][show_meta()] removes them
#'  from the events the next time that the metadata is set). The default,
#'  `FALSE`, removes them from the events.
#' @returns A `move2` object with the specified event data columns added to the
#'  metadata.
#' @export
#' @examples
#' # we first move the sex column to the event data
#' example_tt2 <- as_event_column(example_tt, sex)
#' # and now we move it back to the metadata
#' example_tt2 <- as_meta_column(example_tt2, sex)
#' show_meta(example_tt2)
as_meta_column <- function(x, ..., .keep = FALSE) {
  # the only column in both tables should be the track id
  if (isTRUE(.keep)) {
    lifecycle::deprecate_soft(
      "0.3.0", "as_meta_column(.keep = 'must be FALSE')",
      details = paste(
        "The only column in both the events and the metadata should be the",
        "track id; move the columns back with `as_event_column()` if needed."
      )
    )
  }
  # the columns of the events to move (selected from an empty table with the
  # columns of the events, without its groups)
  cols <- names(dplyr::select(as.data.frame(x)[0, , drop = FALSE], ...))
  # columns that are already in the metadata, with the same values, are not
  # joined again (which would duplicate them, as .x and .y), but only removed
  # from the events (unless .keep is TRUE); with different values, they give
  # an error
  in_meta <- check_same_in_both(x, cols) # nolint: object_usage_linter.
  if (length(in_meta) > 0) {
    if (!.keep) {
      x <- dplyr::select(x, -dplyr::all_of(in_meta))
    }
    cols <- setdiff(cols, in_meta)
    if (length(cols) == 0) {
      return(x)
    }
  }
  move2::mt_as_track_attribute(x, dplyr::all_of(cols), .keep = .keep)
}
