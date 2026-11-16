#' A `ggplot2` geometry to plot events as points
#'
#' @description This function provides a `ggplot2` geometry to plot events as
#'   points. It is a wrapper around `[ggplot2::geom_sf()]`, thus allowing for
#'   projections to be set using the [ggplot2::coord_sf()]` function. See
#'   [ggplot2::geom_sf()] for details
#' @details Events without a location (empty points) are not plotted.
#'
#' @param mapping Set of aesthetic mappings created by [ggplot2::aes()].
#'   Variables from the events table and from the metadata (e.g. the sex of
#'   each animal; see `meta_columns`) can be used for mapping, and to facet the
#'   plot. If none is
#'   provided a basic aesthetics for the `sf` points will be used, as it is the
#'   case for `ggplot2::geom_sf()`.
#' @param data A `move2` object, with the columns from the events table and
#'   from the metadata (see `meta_columns`) available for mapping.
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
#'   geom_event_point(data = example_tt, mapping = aes(color = track_id))
#' # columns of the metadata can be used too
#' ggplot() +
#'   geom_event_point(data = example_tt, mapping = aes(color = sex)) +
#'   facet_wrap(~sex)
#' # only add the columns of the metadata that are needed
#' ggplot() +
#'   geom_event_point(
#'     data = example_tt, mapping = aes(color = sex), meta_columns = "sex"
#'   )
geom_event_point <- function(
  mapping = ggplot2::aes(),
  data = NULL,
  stat = "sf",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  meta_columns = NULL,
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
  # drop the events without a location: they are not drawn, and their empty
  # points break the tweening of the geometries in animate_map()
  data <- data[!sf::st_is_empty(data), ]
  # make the columns of the metadata available for mapping and facets
  data <- with_meta_columns(data, meta_columns)
  # Tag so animate_map() can identify this as a tidytracks track layer.
  attr(data, "tidytracks_geom") <- "event_point"
  attr(data, "tidytracks_data_name") <- data_name
  attr(data, "tidytracks_time_col") <- colname_time(data)

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

#' Add the columns of the metadata to the events of a layer
#'
#' The columns of the metadata (e.g. the sex of each animal) are not in the
#' events, so they could not be used in [ggplot2::aes()], nor to facet a plot,
#' with the events of a `geom_event_*()` layer: they are added to the events of
#' the layer (only for plotting; the `move2` object of the user is not
#' changed). Locations (`sfc` columns) are not added, as `ggplot2` would take
#' them for the geometry of the layer, and neither are columns that are
#' already in the events.
#'
#' @param x A `move2` object.
#' @param meta_columns The names of the columns of the metadata to add: `NULL`
#'   for all of them (other than locations), an empty vector for none.
#' @returns `x`, with the columns of the metadata added to its events.
#' @keywords internal
#' @noRd
with_meta_columns <- function(x, meta_columns = NULL) {
  if (!is.null(meta_columns)) {
    # an empty vector adds no columns (e.g. to save memory with many events)
    if (length(meta_columns) == 0) {
      return(x)
    }
    if (!is.character(meta_columns)) {
      stop(
        "meta_columns must be NULL or the names of columns of the metadata",
        call. = FALSE
      )
    }
  }
  # move2 cannot join an sf table of metadata to the events
  x <- with_plain_meta(x) # nolint: object_usage_linter.
  meta <- show_meta(x)
  is_location <- vapply(meta, inherits, logical(1), what = "sfc")
  if (is.null(meta_columns)) {
    # all the columns of the metadata, other than locations
    meta_columns <- names(meta)[!is_location]
  } else {
    not_in_meta <- setdiff(meta_columns, names(meta))
    if (length(not_in_meta) > 0) {
      stop(
        "meta_columns must be columns of the metadata, which ",
        paste0("'", not_in_meta, "'", collapse = ", "), " are not",
        call. = FALSE
      )
    }
    locations <- intersect(meta_columns, names(meta)[is_location])
    if (length(locations) > 0) {
      stop(
        "meta_columns cannot be locations (sfc columns), which ggplot2 would ",
        "take for the geometry of the layer: ",
        paste0("'", locations, "'", collapse = ", "),
        call. = FALSE
      )
    }
  }
  # the columns that are already in the events (e.g. the track id) are not
  # added again
  cols <- setdiff(meta_columns, names(x))
  if (length(cols) == 0) {
    return(x)
  }
  move2::mt_as_event_attribute(x, dplyr::all_of(cols), .keep = TRUE)
}
