#' Compute the total duration of each track
#'
#' @param x A `move2` object
#' @param units The units to use for the duration. Default is "days".
#' @return A vector of total durations for each track, named by track id and in
#'   the same order as the tracks in the metadata (see [show_meta()])
#' @export
#' @examples
#' track_duration(example_tt)
track_duration <- function(x, units = as_units(1, "days")) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  tot_duration <- do.call(
    c,
    lapply(
      lapply(
        split(event_time(x), event_track_id(x), drop = TRUE),
        range
      ),
      diff
    )
  )
  # split() orders groups by the factor levels of event_track_id(), which
  # are alphabetical, not by the tracks' order in the metadata (which can also
  # differ from the order in which they appear in the events table, e.g. after
  # tt_order_time()). Reorder to match the metadata.
  track_order <- as.character(show_meta(x)[[move2::mt_track_id_column(x)]])
  tot_duration <- tot_duration[track_order]

  # Convert the duration (difftime) to the specified units
  tot_duration <- units::as_units(tot_duration, units)

  return(tot_duration)
}
