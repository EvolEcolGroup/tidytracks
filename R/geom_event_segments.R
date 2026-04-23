#' A `ggplot2` geometry to plot event steps as segments
#'
#' @description This function provides a \code{ggplot2} geometry to plot steps
#'   between events as line segments. Each consecutive pair of events becomes
#'   one LINESTRING, with all event-table variables available for aesthetic
#'   mapping. It is a wrapper around \code{\link[ggplot2]{geom_sf}}, allowing
#'   projections to be set via \code{\link[ggplot2]{coord_sf}}.
#'
#'   Unlike \code{\link{geom_event_path}}, this geometry guarantees a
#'   homogeneous LINESTRING geometry type by dropping the final event of each
#'   track (which has no outgoing step). This makes it compatible with
#'   \code{\link[gganimate]{transition_time}} and is the recommended way to add
#'   track paths to a map that will be animated with
#'   \code{\link{tt_animate_paths}}.
#'
#' @details Units (implemented via the package \code{units}) are produced by
#'   many operations, but are not fully compatible with \code{ggplot2}. This
#'   function internally drops units before creating a \code{ggplot2} layer.
#'
#' @param mapping Set of aesthetic mappings created by \code{\link[ggplot2]{aes}}.
#'   Variables from the events table can be used for mapping.
#' @param data A \code{move2} object. Unlike most \code{ggplot2} geoms, data
#'   must be specified here and is not inherited from the main
#'   \code{\link[ggplot2]{ggplot}} call.
#' @param stat The statistical transformation to use. Default is \code{"sf"},
#'   which should normally be left unchanged.
#' @param position The position adjustment for overlapping geometries. Default
#'   is \code{"identity"}.
#' @param na.rm If \code{FALSE} (default), missing values are removed with a
#'   warning. If \code{TRUE}, they are silently removed.
#' @param show.legend Logical. Should this layer be included in the legends?
#'   Default is \code{NA}, which includes it if any aesthetics are mapped.
#' @param ... Other arguments passed on to \code{\link[ggplot2]{layer}}.
#'
#' @returns A \code{ggplot2} layer object.
#'
#' @export
geom_event_segments <- function(mapping = ggplot2::aes(), data = NULL,
                                stat = "sf",
                                position = "identity",
                                na.rm = FALSE, show.legend = NA,
                                ...) {
  if (is.null(data)) {
    stop("data must be specified for this geometry")
  }
  if (!inherits(data, "move2")) {
    stop("data must be a move2 object")
  }

  data_steps <- data |>
    dplyr::mutate(geometry = move2::mt_segments(data))

  data_steps <- tt_drop_units(data_steps)

  # mt_segments() returns a POINT geometry for the final event of each track
  # (no outgoing step). Filter to LINESTRING only: mixed geometry types break
  # gganimate's transition_time.
  data_steps <- data_steps[sf::st_geometry_type(data_steps) == "LINESTRING", ]

  ggplot2::geom_sf(
    mapping = mapping, data = data_steps, stat = stat,
    position = position, na.rm = na.rm, show.legend = show.legend,
    inherit.aes = FALSE, ...
  )
}
