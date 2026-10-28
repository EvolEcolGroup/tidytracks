#' Compute the total distance of each track
#'
#' @param x A `move2` object
#' @param units The units to use for the distance. Default is "m".
#' @return A vector of total distances for each track, named by track id and in
#'   the same order as the tracks in the metadata (see [show_meta()])
#' @export
#' @examples
#' track_tot_distance(example_tt)
#' track_tot_distance(example_tt, units = "km")
#'
track_tot_distance <- function(x, units = as_units("m")) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # the tracks in the order of the metadata (which can differ from the order
  # in which they appear in the events table, e.g. after tt_order_time())
  track_order <- as.character(show_meta(x)[[move2::mt_track_id_column(x)]])

  # events without a location (empty geometry) have no distance to their
  # neighbours, so they are dropped and the distance is taken between the
  # located events on either side
  empty <- sf::st_is_empty(x)
  if (any(empty)) {
    x <- x[!empty, ]
  }

  # new version: same syntax as track_duration
  tot_distance <- do.call(
    c,
    lapply(
      # splitting by a factor with the tracks as levels returns the tracks in
      # the order of the metadata, including the tracks without any located
      # events (whose distance is 0)
      split(
        event_distance(x),
        factor(as.character(event_track_id(x)), levels = track_order)
      ),
      sum,
      na.rm = TRUE
    )
  )

  # Convert the distance to the specified units
  tot_distance <- units::set_units(tot_distance, units, mode = "standard")

  return(tot_distance)
}
