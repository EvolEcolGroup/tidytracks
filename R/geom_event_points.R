#' A `ggplot2` geometry to plot events as points
#'
#' @description This function provides a `ggplot2` geometry to plot events as
#'   points. It is a wrapper around `[ggplot2::geom_sf()]`, thus allowing for
#'   projections to be set using the [ggplot2::coord_sf()]` function. See
#'   [ggplot2::geom_sf()] for details
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()]. If
#'   specified and `inherit.aes = TRUE` (the default), it is combined with the
#'   default mapping at the top level of the plot. You must supply mapping if
#'   there is no plot mapping. Variables from the events table can be used for
#'   mapping.
#' @param data The data to be displayed in this layer. There are two options:
#'
#'   If NULL, the default, the data is inherited from the plot data as specified
#'   in the call to [ggplot2::ggplot()].
#'
#'   A `move2` object, with the columns from the events table available for
#'   mapping.
#'
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
#' @param inherit.aes If FALSE, overrides the default aesthetics, rather than
#'   combining with them. This is most useful for helper functions that define
#'   both data and aesthetics and shouldn't inherit behaviour from the default
#'   plot.
#' @param ... Other arguments passed on to [ggplot2::layer()].
#' @returns A `ggplot2` layer object.
#' @export

geom_event_points <- function(mapping = ggplot2::aes(), data = NULL,
                              stat = "sf",
                              position = "identity",
                              na.rm = FALSE, show.legend = NA,
                              inherit.aes = TRUE, ...) {
  ggplot2::geom_sf(
    mapping = mapping, data = data, stat = stat,
    position = position, na.rm = na.rm, show.legend = show.legend,
    inherit.aes = inherit.aes, ...
  )
}
