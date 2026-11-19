#' Quantify the home range using minimum convex polygon (MCP)
#'
#' This function estimates the home range of an animal using the minimum convex
#' polygon (MCP) method. Events with an empty geometry (i.e. no location) are
#' ignored.
#'
#' @param x A move2 object; if explicitly grouped, the home range is estimated
#'   for each group, combining all tracks within each group. Otherwise, the
#'   track id is used as grouping variable. Every group must have events, so
#'   groupings with empty groups (e.g. from grouping by a factor with unused
#'   levels with `.drop = FALSE`) give an error.
#' @param levels A vector of levels for the contour lines. The default is
#' `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges.
#' @returns An `sf` tibble of subclass `hr_tt_poly_tbl` of results, with one
#' row per group and level (with the tracks in the order of the metadata, see
#' [show_meta()], if `x` is not grouped, or else with the groups in the order
#' of [dplyr::group_keys()], i.e. sorted by the grouping variables), and
#' columns:
#' - the grouping variables of `x` (the track id if `x` is not grouped), one
#'   column per variable, with the keys of the groups (with their own types,
#'   e.g. a factor, or an `sfc` column of locations from [group_by_meta()])
#' - `method`: the method used to estimate the home range (`"mcp"`)
#' - `level`: the level of the contour line
#' - `area`: the area of the home range (as computed by `sf::st_area()`)
#' - `geometry`: the geometry of the home range as sf polygons; the polygon
#'   is empty, and its area is `NA` (with a warning), if the locations within
#'   the level are fewer than three, or are on a line (e.g. for small levels
#'   or groups with few locations)
#' @details The MCP of a group at a level is the convex hull of the proportion
#'   `level` of its locations that are closest to their centroid (the mean of
#'   their coordinates): the locations whose squared distance from the
#'   centroid is at most the `level` quantile of these squared distances (as
#'   computed by [stats::quantile()]) are kept. A level of 1 gives the convex
#'   hull of all the locations (Mohr 1947). This is the rule of
#'   `amt::hr_mcp()`; `adehabitatHR::mcp()` uses the quantile of the distances
#'   rather than of their squares, which can keep a different set of
#'   locations when the quantile falls between two of them.
#' @references Mohr, C. O. (1947). Table of equivalent populations of North
#'   American small mammals. *American Midland Naturalist*, 37, 223-249.
#'   \doi{10.2307/2421652}
#' @export
#' @examples
#' example_mcp <- hr_tt_mcp(example_tt)
#' example_mcp
#' library(ggplot2)
#' ggplot(example_mcp) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
hr_tt_mcp <- function(x, levels = c(0.5, 0.95)) {
  # if x is not grouped, use the track ID column as grouping variable
  by_track <- !inherits(x, "grouped_df")
  if (by_track) {
    x <- dplyr::group_by(x, .data[[colname_track_id(x)]])
  }
  # as in hr_tt_kde(), every group listed in the group keys must have events
  check_no_empty_groups(x) # nolint: object_usage_linter.

  # Check if levels are valid
  if (
    !is.numeric(levels) ||
      length(levels) == 0 ||
      anyNA(levels) ||
      any(levels < 0 | levels > 1)
  ) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)

  # get the group indices, numbered in the order in which the groups are
  # returned (the order of the tracks in the metadata if x was not grouped,
  # or else the order of the group keys)
  group_order <- hr_group_order(x, by_track) # nolint: object_usage_linter.
  group_index <- match(dplyr::group_indices(x), group_order)
  # the keys of the groups, returned as the first columns, and their labels
  keys <- hr_group_keys(x, group_order) # nolint: object_usage_linter.
  group_labels <- hr_group_labels(keys) # nolint: object_usage_linter.
  # Compute the minimum convex polygon for each group and level
  xy <- sf::st_coordinates(x)
  # events with an empty geometry have no location to contribute to the MCP
  located <- stats::complete.cases(xy)
  xy <- xy[located, , drop = FALSE]
  group_index <- group_index[located]
  # an infinite coordinate makes the distances from the centroid undefined
  if (!all(is.finite(xy))) {
    stop("the coordinates of the locations must be finite")
  }
  # a polygon needs at least 3 locations
  n_locations <- tabulate(group_index, nbins = length(group_labels))
  if (any(n_locations < 3)) {
    stop(
      "each group must contain at least 3 events with a location to compute ",
      "a MCP; groups with fewer locations: ",
      paste(group_labels[n_locations < 3], collapse = ", ")
    )
  }

  # the rows of xy of each group (splitting them once is much faster, with
  # many groups, than finding the rows of each group among all the rows)
  group_rows <- split(
    seq_along(group_index),
    factor(group_index, levels = seq_along(group_labels))
  )

  group_id <- NULL # hack to avoid it being flagged as global in checks
  # one result per group, in the order in which they are returned (rather
  # than in the order in which the groups appear in x); all groups have
  # locations
  geometry <- foreach::foreach(group_id = seq_along(group_labels)) %do% {
    # Create MCP for each level (without a CRS, which is set for all groups
    # at once below)
    mcp_one_group(xy[group_rows[[group_id]], , drop = FALSE], levels)
  }

  # Create a tibble with the results of all groups in one go (creating a
  # tibble for each group and combining them takes much longer when there
  # are many groups), cast it to an sf object, and compute all the areas in
  # one call: sf looks up the parameters of the CRS (with PROJ) every time it
  # computes areas, which takes longer than the MCP of a short track
  mcp_results <- tibble::tibble(
    method = "mcp",
    level = rep(levels, times = length(group_labels)),
    area = NA_real_,
    geometry = sf::st_sfc(unlist(geometry, recursive = FALSE))
  )
  # the keys of the groups come first, one column per grouping variable
  mcp_results <- hr_with_keys( # nolint: object_usage_linter.
    keys,
    mcp_results,
    each = length(levels)
  )
  # the geometry is named, as a grouping variable may be an sfc column
  mcp_results <- sf::st_as_sf(
    mcp_results,
    sf_column_name = "geometry",
    crs = sf::st_crs(x)
  )
  mcp_results$area <- sf::st_area(mcp_results)
  # an MCP with no area (see mcp_polygon()) is returned with an empty geometry
  # and an NA area, with a warning that says why
  empty <- sf::st_is_empty(mcp_results)
  if (any(empty)) {
    mcp_results$area[empty] <- NA
    group_of_row <- rep(seq_along(group_labels), each = length(levels))
    warn_isopleths_not_drawn( # nolint: object_usage_linter.
      lapply(seq_along(group_labels), function(g) {
        isopleths_not_drawn( # nolint: object_usage_linter.
          mcp_results$level[empty & group_of_row == g],
          "mcp_no_area"
        )
      }),
      labels = group_labels
    )
  }

  # add a method attribute
  attr(mcp_results, "hr_tt_method") <- "mcp"
  class(mcp_results) <- c("hr_tt_poly_tbl", class(mcp_results))

  # Return the results as a tt_hr_tt_tbl
  return(mcp_results)
}

#' The MCPs of one group, at several levels
#'
#' Internal function called by `hr_tt_mcp()` for each group: the MCP at a
#' level is the convex hull of the locations whose squared distance from the
#' centroid of the group (the mean of its coordinates) is at most the `level`
#' quantile of these squared distances.
#'
#' @details The quantile is computed as by [stats::quantile()] (type 7, the
#'   default): with `n` locations, it interpolates linearly between the order
#'   statistics at the positions `floor(pos)` and `ceiling(pos)`, where
#'   `pos = 1 + (n - 1) * level`. The order statistics are found with a partial
#'   sort, as `quantile()` does, and the interpolation is the same expression,
#'   so the thresholds are identical to the last bit, without the overhead of
#'   calling `quantile()` for each group.
#'
#' @param xy A matrix of the coordinates of the locations of the group (at
#'   least 3).
#' @param levels A vector of levels, between 0 and 1.
#' @returns An unnamed list of polygons (`sfg` objects), one per level, in the
#'   order of `levels`.
#' @keywords internal
#' @noRd
mcp_one_group <- function(xy, levels) {
  # squared distance of each location from the centroid of the group
  centroid <- colMeans(xy)
  dist2 <- (xy[, 1] - centroid[1])^2 + (xy[, 2] - centroid[2])^2

  # the largest squared distance kept at each level (its type 7 quantile):
  # the two order statistics around position pos, found by a partial sort
  pos <- 1 + (length(dist2) - 1) * levels
  pos_low <- floor(pos)
  pos_high <- ceiling(pos)
  sorted <- sort.int(dist2, partial = unique(c(pos_low, pos_high)))
  max_dist2 <- sorted[pos_low]
  # interpolate between them where pos is not a whole number and they differ
  # (the condition and the expression of quantile())
  frac <- pos - pos_low
  interp <- which(frac > 0 & sorted[pos_high] != max_dist2)
  max_dist2[interp] <- (1 - frac[interp]) * max_dist2[interp] +
    frac[interp] * sorted[pos_high[interp]]

  # the MCP of each level: the convex hull of the locations within its
  # distance (kept in their original order, as the vertices that
  # grDevices::chull() returns among duplicated or collinear locations can
  # depend on it)
  lapply(max_dist2, function(d2) {
    mcp_polygon(xy[dist2 <= d2, , drop = FALSE])
  })
}

#' The convex hull of a set of locations, as a polygon
#'
#' @param xy A matrix of the coordinates of the locations.
#' @returns A polygon (an `sfg` object): the convex hull of the locations
#'   (from [grDevices::chull()]), or an empty polygon if the hull has fewer
#'   than 3 vertices.
#' @keywords internal
#' @noRd
mcp_polygon <- function(xy) {
  # the indices of the vertices of the hull, in clockwise order
  vertices <- grDevices::chull(xy)
  # grDevices::chull() can return two vertices at the same place (a location
  # and its duplicate, e.g. with rounded coordinates); keep only the first,
  # as a repeated vertex makes an edge of length zero, which s2 rejects (for
  # longitudes and latitudes). The places are compared exactly, as complex
  # numbers, which duplicated() hashes quickly.
  places <- complex(real = xy[vertices, 1], imaginary = xy[vertices, 2])
  vertices <- vertices[!duplicated(places)]
  # if the locations are all at the same place or on a line, the hull has
  # fewer than 3 vertices: it has no area, and a polygon made from it would
  # be invalid (and rejected by s2 for unprojected data), so return an empty
  # polygon instead
  if (length(vertices) < 3) {
    return(sf::st_polygon())
  }
  # the ring of the polygon, closed by repeating its first vertex; the
  # polygon is built directly, as the identical object sf::st_polygon()
  # would return, as its checks take longer than the hull itself (this is
  # called for each group and level)
  ring <- xy[c(vertices, vertices[1]), 1:2, drop = FALSE]
  structure(list(ring), class = c("XY", "POLYGON", "sfg"))
}


# deprecated function for backward compatibility
#' @rdname tidytracks-deprecated
#' @export
hr_mcp <- function(x, levels = c(0.5, 0.95)) {
  warning("hr_mcp is deprecated. Please use hr_tt_mcp instead.", call. = FALSE)
  hr_tt_mcp(x = x, levels = levels)
}
