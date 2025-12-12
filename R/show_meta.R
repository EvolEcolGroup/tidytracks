#' Show or set the track metadata of a `move2` object
#'
#' @param x A move2 object
#' @return The metadata table from the input `move2` object
#' @export

show_meta <- move2::mt_track_data


#' @rdname show_meta
#' @param value A data frame with metadata to set for the `move2` object
#' @export
#' @return The modified `move2` object with updated metadata
#' @examples
#' show_meta(boobies_mt)$new_column <- "example_info"

"show_meta<-" <- function(x, value) {
  x <- move2::mt_set_track_data(x, value)
  return(x)
}
