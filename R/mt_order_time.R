#' Order a `move2` object by time within each track_id
#'
#' A helper function to order a `move2` object by time within each track_id.
#' Note that it also reorders
#' the track_ids. Several functions require tracks to be ordered by time to work
#' properly
#'
#' @param x A `move2` object
#' @return A `move2` object ordered by time
#' @export

mt_order_time <- function(x) {
  return(x[order(move2::mt_track_id(x), move2::mt_time(x)), ])
}
