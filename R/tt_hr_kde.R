#' Quantify the home range using kernel density estimation
#'
#' This function estimates the home range of an animal using kernel density
#' estimation (KDE).
#'
#' @param x A grouped move2 object
#' @param h The bandwidth for the kernel density estimation. It defaults
#' to href.
#' @param grid Either a named vector of length 5, with values xmin, ymin,
#' xmax, ymax, and n (the number of cells in the grid);
#' or a terra::SpatRaster object. If null, the extent is taken by combining
#' all points in `x`, and the number of cells is set to 1000.
#' @param levels A vector of levels for the contour lines. The default is
#' `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges.
#' @param keep_objects whether the individual KDE objects should be kept
#' as a column in the output object. This is useful for debugging, but
#' will increase the size of the object.
#' @returns A tibble of subclass `tt_hr_tbl` of results, with columns:
#' - `group_id`: the ids from the groping of `x`
#' - `.level_XX`: the sf polygons for level XX; the number of this type of
#' column depends on the length of `levels`
#' - `kde`: the KDE object used to create the polygons (if
#' `keep_objects = TRUE`)
#' @export

tt_hr_kde <- function(x, h = NULL, grid = NULL, levels = c(0.5, 0.95),
                keep_objects = FALSE) {
  # Check if x is a grouped move2 object
  if (!inherits(x, "move2") || !inherits(x, "grouped_df")) {
    stop("x must be a grouped move2 object")
  }
  coords <- sf::st_coordinates(x)

  # Check if h is provided
  if (is.null(h)) {
    h <- ade_href(coords)
  }

  browser()

  # Check if grid is provided
  if (is.null(grid)) {
    # get extend of x, which is an sf object
    grid <- sf::st_bbox(x)
    grid <- list(xmin = min(x$x), ymin = min(x$y),
                 xmax = max(x$x), ymax = max(x$y), n = 1000)
  } else if (inherits(grid, "SpatRaster")) {
    grid <- terra::ext(grid)
    grid <- list(xmin = grid[1], ymin = grid[2],
                 xmax = grid[3], ymax = grid[4], n = terra::ncell(grid))
  } else if (length(grid) != 5) {
    stop("grid must be a named vector of length 5 or a SpatRaster object")
  } else if (!all(c("xmin", "ymin", "xmax", "ymax", "n") %in% names(grid))) {
    stop("grid must be a named vector of length 5 with names xmin, ymin, xmax, ymax, and n")
  }

  kde2d(x[,1],
        x[,2],
        n = c(100, 100),
        h = h,
        lims = c(range(mask.xy$x), range(mask.xy$y))
  )
}


ade_href <- function(x) {
  h_ref <- (sqrt(0.5 * (var(x[,1]) + var(x[,2])))) * (nrow(x)^-(1 / 6))
  return(h_ref*4) # needed to match href in adehabitatHR
}

