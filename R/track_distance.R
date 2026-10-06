#' Compute the total distance of each track
#'
#' @param x A `move2` object
#' @return A vector of total distances for each track
#' @export
#' @examples
#' track_distance(example_tt)
#' 

track_distance <- function(x) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  
  # Name of the track ID column
  track_col <- move2::mt_track_id_column(x)
  
  df <- x %>%
    # Distance to the next point (last point of each track is NA)
    dplyr::mutate(distance = units::as_units(event_distance(x))) %>%
    # Drop geometry so it isn't carried into the output
    sf::st_drop_geometry() %>%
    dplyr::group_by(.data[[track_col]]) %>%
    dplyr::summarise(
      tot_distance = sum(.data$distance, na.rm = TRUE),
      .groups = "drop"
    )
  
# reorder to match the order tracks first appear in x
  track_order <- as.character(unique(event_track_id(x)))
  df <- df[match(track_order, df[[track_col]]), ]
  
  # Return a named vector of total distances
  tot_distance <- df$tot_distance
  names(tot_distance) <- df[[track_col]]
  
  return(tot_distance)
}



