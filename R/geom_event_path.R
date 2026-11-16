#' A `ggplot2` geometry to plot event steps as paths
#'
#' @description This function provides a `ggplot2` geometry to plot steps
#'   between events as paths. It uses [move2::mt_segments()] to create `sf`
#'   lines joining each consecutive pair of events (i.e. steps. These steps are
#'   then added to the events table (with a point for the last event of each
#'   track), so that all variables in the event table are available for mapping
#'   the aesthetics. The resulting `sf` lines are then plotted via a wrapper
#'   around `[ggplot2::geom_sf()]`, thus allowing for projections to be set
#'   using the [ggplot2::coord_sf()]` function. See [ggplot2::geom_sf()] for
#'   details.
#' @details Units (implemented via the package `units`) are produced by many
#'   operations, but are not fully compatible with `ggplot2`. This function
#'   internally drops units before creating a `ggplot2` layer.
#'
#'   Events without a location (empty points) are skipped, so that each step
#'   joins consecutive events with a location.
#'
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()].
#'   Variables from the *events* table and from the metadata (e.g. the sex of
#'   each animal; see `meta_columns`) can be used for mapping, and to facet the
#'   plot. If none is provided a basic aesthetics
#'   for the `sf` step segments (i.e. lines) will be used, as it is the case for
#'   `ggplot2::geom_sf()`.
#' @param data The `move2` object to be displayed. For this geometry, there is
#'   no inheritance from the main `ggplot()` call, and data has to be specified.
#' @param drop_final_point Logical, default is `TRUE`. The `move2::mt_segments`
#'   function cannot create a segment for the final point in each track, so it
#'   is left as a `POINT` geometry. If `TRUE`, we filter to `LINESTRING`
#'   geometries only (this is necessary for the animation function to work).
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
#' @param meta_columns The names of the columns of the metadata to add to the
#'   events of the layer, for mapping and facets. `NULL`, the default, adds all
#'   of them (other than locations, i.e. `sfc` columns); an empty vector,
#'   `character(0)`, adds none, which saves memory with many events (note that
#'   `c()` is `NULL` in R, and so adds all of them).
#' @param ... Other arguments passed on to [ggplot2::layer()].
#' @returns A `ggplot2` layer object.
#' @export
#' @examples
#' library(ggplot2)
#' ggplot() +
#'   geom_event_path(data = example_tt, mapping = aes(color = track_id))
#' # columns of the metadata can be used too
#' ggplot() +
#'   geom_event_path(data = example_tt, mapping = aes(color = sex)) +
#'   facet_wrap(~sex)
geom_event_path <- function(
  mapping = ggplot2::aes(),
  data = NULL,
  drop_final_point = TRUE,
  stat = "sf",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  meta_columns = NULL,
  ...
) {
  data_name <- deparse(substitute(data))
  # check that data is not NULL
  if (is.null(data)) {
    stop("data must be specified for this geometry")
  }
  # check that data is a move2 object
  if (!inherits(data, "move2")) {
    stop("data must be a move2 object")
  }

  # replace the points in the (active) geometry column, whatever its name, by
  # the segments between each pair of points, using move2::mt_segments.
  # mt_segments() requires non-empty points, so events without a location are
  # dropped first: each step then joins consecutive located events
  data_steps <- data[!sf::st_is_empty(data), ]
  sf::st_geometry(data_steps) <- move2::mt_segments(data_steps)
  # make the columns of the metadata available for mapping and facets
  data_steps <- with_meta_columns( # nolint: object_usage_linter.
    data_steps, meta_columns
  )

  # drop all units
  data_steps <- tt_drop_units(data_steps)

  # mt_segments() returns a POINT geometry for the final event of each track
  # (no outgoing step). IF drop_final_point - TRUE, filter to LINESTRING only:
  # mixed geometry types break gganimate's transition_time.
  if (
    !is.logical(drop_final_point) ||
      length(drop_final_point) != 1L ||
      is.na(drop_final_point)
  ) {
    stop("drop_final_point must be TRUE or FALSE")
  }
  if (drop_final_point) {
    data_steps <- data_steps[sf::st_geometry_type(data_steps) == "LINESTRING", ]
  }

  # Tag so animate_map() can identify this as a tidytracks track layer.
  attr(data_steps, "tidytracks_geom") <- "event_path"
  attr(data_steps, "tidytracks_data_name") <- data_name
  attr(data_steps, "tidytracks_time_col") <- colname_time(data)

  ggplot2::geom_sf(
    mapping = mapping,
    data = data_steps,
    stat = stat,
    position = position,
    na.rm = na.rm,
    show.legend = show.legend,
    inherit.aes = FALSE,
    ...
  )
}
