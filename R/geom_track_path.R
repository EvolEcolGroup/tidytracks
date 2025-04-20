#' A `ggplot2` geometry to plot tracks as paths
#'
#' @description This function provides a `ggplot2` geometry to plot track as
#'   paths. It uses [track_lines()] to create `sf` multilines which are then
#'   plotted via a wrapper around `[ggplot2::geom_sf()]`, thus allowing for
#'   projections to be set using the [ggplot2::coord_sf()]` function. See
#'   [ggplot2::geom_sf()] for details. All variables from the metadata table can
#'   be used for mapping.
#'
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()]. You
#'   must supply mapping for this geometry, there is no inheritance from the
#'   main `ggplot()` call. Variables from the metadata table can be used for
#'   mapping.
#' @param data The `move2` object to be displayed. For this geometry, there is
#'   no inheritance from the main `ggplot()` call, and data has to be specified.
#' @param stat The statistical transformation to use on the data for this layer.
#'   The default is "sf", which should normally be left unchanged.
#' @param position The position adjustment to use for overlapping points on this
#'   layer. The default is "identity", meaning no adjustment will be made to the
#'   data.
#' @param na.rm If FALSE, the default, missing values are removed with a
#'   warning. If TRUE, missing values are silently removed.
#' @param show.legend logical. Should this layer be included in the legends? The
#'   default is NA, which includes if any aesthetics are mapped. It can also be
#'   a named logical vector to finely select the aesthetics to display.
#' @param ... Other arguments passed on to [ggplot2::layer()].
#' @returns A `ggplot2` layer object.
#' @export

geom_track_path <- function(mapping = NULL, data = NULL, stat = "sf",
                               position = "identity",
                               na.rm = FALSE, show.legend = NA,
                               ...) {

  # check that mapping is not NULL
  if (is.null(mapping)) {
    stop("mapping must be specified for this geometry")
  }
  # check that data is not NULL
  if (is.null(data)) {
    stop("data must be specified for this geometry")
  }
  # check that data is a move2 object
  if (!inherits(data, "move2")) {
    stop("data must be a move2 object")
  }
  data_lines <- track_lines(data)
  ggplot2::geom_sf(mapping = mapping, data = data_lines, stat = stat,
          position = position, na.rm = na.rm, show.legend = show.legend,
          inherit.aes = FALSE, ...)
}
