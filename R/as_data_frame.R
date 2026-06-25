#' Convert a `move2` object to a data frame
#'
#' This function converts a `move2` object into a data frame, including the
#' event data and the associated metadata. The resulting data frame will have
#' one row per event, with columns for the event attributes, the track ID, and
#' the metadata attributes (unless `include_meta` is set to `FALSE`).
#' @param x A `move2` object
#' @param ...	additional arguments to be passed to or from methods.
#' @param include_meta Logical, whether to include the metadata attributes in
#'   the resulting data frame. Default is TRUE.
#' @return A data frame with one row per event, including the event attributes,
#'   track
#' @export
#' @rdname as_data_frame_move2
#' @examples
#' # example code
#' as.data.frame(example_tt)

as.data.frame.move2 <- function(x, ..., include_meta = TRUE) {

  # If include_meta is TRUE, join the metadata attributes to the data frame
  if (include_meta) {
    x <- x |> move2::mt_as_event_attribute(dplyr::any_of(names(show_meta(x))))
  }
  # drop the geometry column and convert to a data frame
  cbind(x |>
    dplyr::select(-dplyr::all_of("geometry")) |>
    NextMethod() |>   # Convert the move2 object to a data frame
    dplyr::select(
      -dplyr::all_of("geometry"),  # drop geom column
    ),
    sf::st_coordinates(x)) # add the coordinates as individual columns


  #NextMethod()
}