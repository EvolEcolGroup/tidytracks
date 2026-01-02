#' Show or set the track metadata of a `move2` object
#' 
#' The track metadata is stored as a data frame within the `move2` object. This
#' function allows you to view or modify this metadata. When retrieving the
#' metadata, it returns a tibble containing the metadata for each track. When
#' setting the metadata, you can provide a new data frame with the updated
#' metadat, or modify or remove specific columns, as you would normally do with
#' a data.frame/tibble. If providing a new metadata table, make sure that 
#' the number of rows matches the number of tracks in the `move2` object, and
#' that the track IDs correspond to those in the `move2` object.
#' @param x A move2 object
#' @return The metadata table from the input `move2` object (nothing is
#' returned if using the setter function).
#' @export
#' @examples
#' show_meta(shags_tt)
#' show_meta(shags_tt)$new_column <- "example_info"
#' show_meta(shags_tt)

show_meta <- move2::mt_track_data

#' @rdname show_meta
#' @param value A data frame with metadata to set for the `move2` object
#' @export
"show_meta<-" <- function(x, value) {
  x <- move2::mt_set_track_data(x, value)
  return(x)
}
