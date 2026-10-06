#' Compute the total distance of each track
#'
#' @param x A `move2` object
#' @return A vector of total distances for each track
#' @export
#' @examples
#' track_tot_distance(example_tt)
#'
track_tot_distance <- function(x) {
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
  return(tot_distance)
}
