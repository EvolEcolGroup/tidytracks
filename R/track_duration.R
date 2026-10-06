#' Compute the total duration of each track
#'
#' @param x A `move2` object
#' @param units The units to use for the duration. Default is "days".
#' @return A vector of total durations for each track
#' @export
#' @examples
#' track_duration(example_tt)
track_duration <- function(x, units = as_units(1, "days")) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  tot_duration <- do.call(
    # The inner lapply() calls produce a *list* of single-value difftimes
    # (one per track), not a vector. do.call(c, ...) concatenates that list
    # into one combined difftime vector, preserving each element's name
    # (the track ID) as the resulting vector's names.
    c,
    lapply(
      lapply(
        # split() breaks the vector of event timestamps into a named list
        # of timestamp vectors, one per track, using the track ID as the
        # grouping factor. drop = TRUE removes any unused factor levels
        # (tracks with no events) from the list.
        split(event_time(x), event_track_id(x), drop = TRUE),
        # For each track's vector of timestamps, range() returns a
        # length-2 vector: c(earliest timestamp, latest timestamp).
        range
      ),
      # diff() on a length-2 range gives a single value: latest - earliest,
      # i.e. the track's total duration (as a difftime).
      diff
    )
  )
  # split() orders groups by the factor levels of event_track_id(), which
  # are alphabetical, not by the tracks' original order of appearance.
  # Reorder to match the order tracks first appear in x.
  track_order <- as.character(unique(event_track_id(x)))
  tot_duration <- tot_duration[track_order]

  # Convert the duration (difftime) to the specified units
  tot_duration <- units::as_units(tot_duration, units)

  return(tot_duration)
}
