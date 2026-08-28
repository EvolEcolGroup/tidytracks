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
    c,
    lapply(
      lapply(
        split(event_time(x), event_track_id(x), drop = TRUE),
        range
      ),
      diff
    )
  )
  # Convert the duration (difftime) to the specified units
  tot_duration <- units::as_units(tot_duration, units)

  return(tot_duration)
}
