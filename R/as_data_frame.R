#' Convert a `move2` object to a data frame
#'
#' This function converts a `move2` object into a data frame, including the
#' event data and the associated metadata. The resulting data frame will have
#' one row per event, with columns for the event attributes, the track ID, and
#' the metadata attributes (unless `include_meta` is set to `FALSE`).
#' @param x A `move2` object
#' @param ...	additional arguments to be passed to or from methods.
#' @param include_meta Logical, whether to include the metadata attributes in
#'   the resulting data frame. Default is FALSE.
#' @param drop_geometry Logical, whether to drop the geometry column from the
#'  resulting data frame. Default is FALSE. If TRUE, the coordinates are stored
#'  in separate columns (`X` and `Y`).
#' @return A data frame with one row per event, including event attributes, the
#'   track ID, and optionally metadata attributes.
#' @export
#' @rdname as_data_frame_move2
#' @examples
#' # example code
#' as.data.frame(example_tt, include_meta = TRUE, drop_geometry = TRUE)
as.data.frame.move2 <- function(
  x,
  ...,
  include_meta = FALSE,
  drop_geometry = FALSE
) {
  # If include_meta is TRUE, join the metadata attributes to the data frame
  if (include_meta) {
    x <- x |> move2::mt_as_event_attribute(dplyr::any_of(names(show_meta(x))))
  }

  # Convert the move2 object to a data frame (NextMethod() passes on the
  # current value of x, i.e. including the metadata if requested)
  df <- NextMethod()
  if (drop_geometry) {
    # drop the geometry column, and add the coordinates as individual columns
    df <- cbind(
      dplyr::select(df, -dplyr::all_of(attr(x, "sf_column"))),
      sf::st_coordinates(x)
    )
  }
  df
}
