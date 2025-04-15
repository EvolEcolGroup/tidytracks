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

  # get the group indices
  group_index <- dplyr::group_indices(x)
  group_unique <- unique(group_index)
  # Compute the minimum convex polygon for each group and level
  foreach::foreach(
    group_id = group_unique,
    .combine = dplyr::bind_rows
  ) %do% {
    # Filter the data for the current group
    x_group <- x[group_index == group_id, ]
    # Extract coordinates
    xy <- sf::st_coordinates(x_group)
    # Create MCP for each level
    geometry <- one_group_mcp(xy, levels,
                              dplyr::group_keys(x)[group_id],
                              crs = sf::st_crs(x))
    # Calculate area
#    area <- sf::st_area(geometry)
    # Create a tibble with the results
    tibble::tibble(
      group_id = group_id,
      level = levels,
#      area = area,
      geometry = geometry
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
#' @param x a sf tibble of coordinates for a single group (coming via group_map
#' it will lose the move2 class, but it is an sf)
#' @param levels A vector of levels for the contour lines
#' @param group_id The ID of the group
#' @param units The units to use for the area
#' @returns A tibble of subclass `tt_hr_tbl` of results, with columns:
#' - `group_id`: the ID of the group
#' - `level`: the level of the contour line
#' - `area`: the area of the home range in map units
#' - `geometry`: the geometry of the home range as a list of sf polygons
#' @keywords internal

one_group_mcp <- function(x, levels, group_id, crs) {

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
