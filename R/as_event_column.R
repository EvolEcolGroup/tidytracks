#' Move one (or more) variable(s) from the metadata to the event data as a new
#' column(s).
#'
#' This function moves one or more columns from the metadata of a `move2` object
#' to the event data, adding them as new columns. This is useful when you want
#' to include metadata information in the event-level analysis.
#' @param x A `move2` object
#' @param ... One or more unquoted column names from the metadata to move to the
#'   event data; it is possible to use tidyselect helpers to select multiple
#'   columns.
#' @param .keep A logical value indicating whether to keep the original metadata
#'   columns in the metadata after moving them to the event data. The default is
#'   `FALSE`, which means that the original metadata columns will be removed.
#' @returns A `move2` object with the specified metadata columns added to the
#'   event data.
#' @export
#' @examples
#' example_tt2 <- as_event_column(example_tt, sex)
#' example_tt2 # now showing sex in the events table

as_event_column <- function(x, ..., .keep = FALSE) {
  move2::mt_as_event_attribute(x, ..., .keep = .keep)
}
