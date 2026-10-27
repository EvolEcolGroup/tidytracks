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
#' row per group and level, and columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`
#' - `method`: the method used to estimate the home range (`"mcp"`)
#' - `level`: the level of the contour line
#' - `area`: the area of the home range (as computed by `sf::st_area()`)
#' - `geometry`: the geometry of the home range as sf polygons
#' @export
#' @examples
#' example_mcp <- hr_tt_mcp(example_tt)
#' example_mcp
#' library(ggplot2)
#' ggplot(example_mcp) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
hr_tt_mcp <- function(x, levels = c(0.5, 0.95)) {
  # if x is not grouped, use the track ID column as grouping variable
  if (!inherits(x, "grouped_df")) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  # as in hr_tt_kde(), every group listed in the group keys must have events
  check_no_empty_groups(x) # nolint: object_usage_linter.

  # Check if levels are valid
  if (any(levels < 0 | levels > 1)) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)

  # get the group indices
  group_index <- dplyr::group_indices(x)
  group_unique <- unique(group_index)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  # Compute the minimum convex polygon for each group and level
  xy <- sf::st_coordinates(x)
  # events with an empty geometry have no location to contribute to the MCP
  located <- stats::complete.cases(xy)
  xy <- xy[located, , drop = FALSE]
  group_index <- group_index[located]
  # a polygon needs at least 3 locations
  n_locations <- tabulate(group_index, nbins = length(group_labels))
  if (any(n_locations < 3)) {
    stop(
      "each group must contain at least 3 events with a location to compute ",
      "a MCP; groups with fewer locations: ",
      paste(group_labels[n_locations < 3], collapse = ", ")
    )
  }

  group_id <- NULL # hack to avoid it being flagged as global in checks
  mcp_results <- foreach::foreach(group_id = group_unique) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, , drop = FALSE]
    # Create MCP for each level (without a CRS, which is set for all groups
    # at once below)
    geometry <- mcp_one_group(xy_sub, levels)

    # Create a tibble with the results (areas are computed below)
    tibble::tibble(
      group_id = group_labels[group_id],
      method = "mcp",
      level = levels,
      area = NA_real_,
      geometry = geometry
    )
  }

  # Combine the groups in one go (combining them one at a time, as foreach's
  # .combine does, takes time quadratic in the number of groups), cast the
  # results to an sf object, and compute all the areas in one call: sf looks
  # up the parameters of the CRS (with PROJ) every time it computes areas,
  # which takes longer than the MCP of a short track
  mcp_results <- dplyr::bind_rows(mcp_results)
  mcp_results <- sf::st_as_sf(mcp_results, crs = sf::st_crs(x))
  mcp_results$area <- sf::st_area(mcp_results)

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    mcp_results <- mcp_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x),
        dplyr::all_of("group_id")
      )
  }

  # add a method attribute
  attr(mcp_results, "hr_tt_method") <- "mcp"
  class(mcp_results) <- c("hr_tt_poly_tbl", class(mcp_results))

  # Return the results as a tt_hr_tt_tbl
  return(mcp_results)
}

#' Create mcp at multiple levels for a given group
#'
#' This is the internal function that is called by `hr_tt_mcp` to create the MCP
#' at multiple levels for a given group. It is not intended to be called
#' directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param levels A vector of levels for the contour lines
#' @returns An `sfc` of polygons (without a CRS) representing the MCP at each
#'   level
#' @keywords internal
#' @noRd
mcp_one_group <- function(xy, levels) {
  mxy <- colMeans(xy)
  sqd <- (xy[, 1] - mxy[1])^2 + (xy[, 2] - mxy[2])^2
  qts <- stats::quantile(sqd, levels)
  geometry <- lapply(qts, function(i) chull_mcp(xy[sqd <= i, , drop = FALSE]))
  sf::st_sfc(geometry)
}

# chull function from amt package (or shall we use sf::st_convex_hull?)
chull_mcp <- function(x) {
  x <- as.matrix(x)
  ch <- grDevices::chull(x)
  ch <- c(ch, ch[1])
  sf::st_polygon(list(x[ch, 1:2]))
}


# deprecated function for backward compatibility
#' @rdname tidytracks-deprecated
#' @export
hr_mcp <- function(x, levels = c(0.5, 0.95)) {
  warning("hr_mcp is deprecated. Please use hr_tt_mcp instead.", call. = FALSE)
  hr_tt_mcp(x = x, levels = levels)
}
