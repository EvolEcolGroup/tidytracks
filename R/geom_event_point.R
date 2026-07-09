#' A `ggplot2` geometry to plot events as points
#'
#' @description This function provides a `ggplot2` geometry to plot events as
#'   points. It is a wrapper around `[ggplot2::geom_sf()]`, thus allowing for
#'   projections to be set using the [ggplot2::coord_sf()]` function. See
#'   [ggplot2::geom_sf()] for details
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()].
#'   Variables from the events table can be used for mapping. If none is
#'   provided a basic aesthetics for the `sf` points will be used, as it is the
#'   case for `ggplot2::geom_sf()`.
#' @param data A `move2` object, with the columns from the events table
#'   available for mapping.
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

geom_event_point <- function(
  mapping = ggplot2::aes(),
  data = NULL,
  stat = "sf",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  ...
) {
  data_name <- deparse(substitute(data))
  # data can not be null
  if (is.null(data)) {
    stop("data must be specified for this geometry")
  }
  # check that data is a move2 object
  if (!inherits(data, "move2")) {
    stop("data must be a move2 object")
  }
  # drop the units, as they are not compatible with ggplot
  data <- tt_drop_units(data)
  # Tag so animate_map() can identify this as a tidytracks track layer.
  attr(data, "tidytracks_geom") <- "event_point"
  attr(data, "tidytracks_data_name") <- data_name
  attr(data, "tidytracks_time_col") <- move2::mt_time_column(data)

  ggplot2::geom_sf(
    mapping = mapping,
    data = data,
    stat = stat,
    position = position,
    na.rm = na.rm,
    show.legend = show.legend,
    inherit.aes = FALSE,
    ...
  )
}
