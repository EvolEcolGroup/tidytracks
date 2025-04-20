#' Quantify the home range using minimum convex polygon (MCP)
#'
#' This function estimates the home range of an animal using the minimum convex
#' polygon (MCP) method.
#'
#' @param x A grouped move2 object
#' @param levels A vector of levels for the contour lines. The default is
#' `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges.
#' @returns A tibble of subclass `tt_hr_tbl` of results, with columns:
#' - `group_id`: the ids from the groping of `x`
#' - `level`: the level of the contour line
#' - `geometry`: the geometry of the home range as a list of sf polygons
#' @export

tt_hr_mcp <- function(x, levels = c(0.5, 0.95)) {
  # Check if x is a grouped move2 object
  if (!inherits(x, "move2") || !inherits(x,"grouped_df")) {
    stop("x must be a grouped move2 object")
  }

  # Check if levels are valid
  if (any(levels < 0 | levels > 1)) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)

  # get the group indices
  group_index <- dplyr::group_indices(x)
  group_unique <- unique(group_index)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col="group_labels") %>%
    dplyr::pull(1)
  # Compute the minimum convex polygon for each group and level
  xy <- sf::st_coordinates(x)

  group_id <- NULL # hack to avoid it being flagged as global in checks
  mcp_results <- foreach::foreach(
    group_id = group_unique,
    .combine = dplyr::bind_rows
  ) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, ]
    # Create MCP for each level
    geometry <- mcp_one_group(xy_sub, levels,
                              crs = sf::st_crs(x))
    # Calculate area
#    area <- sf::st_area(geometry)

    # Create a tibble with the results
    tibble::tibble(
      group_id = group_labels[group_id],
      level = levels,
#      area = area,
      geometry = geometry
    )
  }

  # now cast the results to an sf object
  mcp_results <- sf::st_as_sf(mcp_results, crs = sf::st_crs(x))
  # add a method attribute
  attr(mcp_results, "hr_method") <- c("mcp")

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    mcp_results <- mcp_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x), dplyr::all_of("group_id")
      )
  }

  # Return the results as a tt_hr_tbl
  return(mcp_results)
}

#' Create mcp at multiple levels for a given group
#'
#' This is the internal function that is called by `tt_hr_mcp` to create the MCP
#' at multiple levels for a given group. It is not intended to be called
#' directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param levels A vector of levels for the contour lines
#' @param crs the crs of the coordinates (to use in the geometry)
#' @returns A list of sf polygons representing the MCP at each level
#' @keywords internal

mcp_one_group <- function(xy, levels,crs) {

  mxy <- colMeans(xy)
  sqd <- (xy[,1] - mxy[1])^2 + (xy[,2] - mxy[2])^2
  qts <- stats::quantile(sqd, levels)
  geometry <- lapply(qts, function(i) chull_mcp(xy[sqd <= i, ]))
  geometry <- sf::st_as_sfc(geometry, crs = crs)
}

# chull function from amt package (or shall we use sf::st_convex_hull?)
chull_mcp <- function(x) {
  x <- as.matrix(x)
  ch <- grDevices::chull(x)
  ch <- c(ch, ch[1])
  sf::st_polygon(list(x[ch, 1:2]))
}
