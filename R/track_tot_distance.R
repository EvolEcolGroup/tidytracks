#' Compute the total distance of each track
#'
#' @param x A `move2` object
#' @param units The units to use for the distance. Default is "m".
#' @return A vector of total distances for each track
#' @export
#' @examples
#' track_tot_distance(example_tt)
#' track_tot_distance(example_tt, units = "km")
#'
track_tot_distance <- function(x, units = as_units("m")) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # new version: same syntax as track_duration
  tot_distance <- do.call(
    c,
    lapply(
      split(event_distance(x), event_track_id(x), drop = TRUE),
      sum, na.rm = TRUE
    )
  )
  # Reorder to match the order tracks first appear in x.
  track_order <- as.character(unique(event_track_id(x)))
  tot_distance <- tot_distance[track_order]

  # Convert the distance to the specified units
  tot_distance <- units::set_units(tot_distance, units, mode = "standard")

  return(tot_distance)
}
