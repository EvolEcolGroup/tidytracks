#' Quantify the home range using kernel density estimation
#'
#' This function estimates the home range of an animal using kernel density
#' estimation (KDE).
#'
#' @param x A grouped move2 object
#' @param h The bandwidth for the kernel density estimation. It defaults
#' to href.
#' @param grid A list of length 5, with values xmin, ymin,
#' xmax, ymax and res (all in the units of the projection of x).
#' If null, the extent is taken by combining
#' all points in `x` (expanded by 10%), and the number of cells is set to 1000.
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

tt_hr_kde <- function(x, h = "h_ref_mean", grid = NULL, levels = c(0.5, 0.95),
                keep_objects = FALSE) {
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
  # check h
  if (!is.numeric(h)){
    h <- match.arg(h, c("h_ref_mean", "h_ref_indiv",
                     "h_ref_ade_mean", "h_ref_ade_indiv"))
    h_fun <- get(h) # assign the function to h_fun
    h <- h_fun(xy, group_index) # compute h
  }
  if (length(h) == 1) {
    h <- rep(h, length(group_unique))
  } else if (length(h) != length(group_unique)) {
    stop("h must be a single value or a vector of the same length as the number of groups in x")
  }

  # Check if grid is provided
  if (is.null(grid)) {
    # get extend of x, which is an sf object
    grid_bbox <- sf::st_bbox(x)
    # extend the grid by a fixed factor
    # TODO compare to amt (extending by 50%), adehabitatHR (extending by 1)
    # and track2kba (extending by 0.05 or h*2000, whichever is larger))
    extend_x <- (grid_bbox$xmax-grid_bbox$xmin) * 1
    extend_y <- (grid_bbox$ymax-grid_bbox$ymin) * 1

    grid <- list(xmin = grid_bbox$xmin - extend_x,
                 ymin = grid_bbox$ymin - extend_y,
                 xmax = grid_bbox$xmax + extend_x,
                 ymax = grid_bbox$ymax + extend_y)
    # set resolution to get a 1000 cells
    grid[["res"]] <- sqrt( (grid$xmax-grid$xmin) *
                             (grid$ymax-grid$ymin)/1500)
    # update the max to be an exact multiple of res
    grid[["xmax"]] <- grid$xmin + ceiling((grid$xmax-grid$xmin)/grid$res) * grid$res
    grid[["ymax"]] <- grid$ymin + ceiling((grid$ymax-grid$ymin)/grid$res) * grid$res

  } else if (length(grid) != 5) {
    stop("grid must be a named vector of length 5")
  } else if (!all(c("xmin", "ymin", "xmax", "ymax", "res") %in% names(grid))) {
    stop("grid must be a list of length 5 with names xmin, ymin, xmax, ymax, and res")
  }

  group_id <- NULL # hack to avoid it being flagged as global in checks
  kde_results <- foreach::foreach(
    group_id = group_unique,
    .combine = rbind #dplyr::bind_rows
  ) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, ]
    h_val <- h[group_id]
    # Create kernel for each level
    geometry <- kde_one_group(xy_sub, levels,
                              crs = sf::st_crs(x),
                              grid = grid,
                              h = h_val,
                              keep_object = keep_objects)
    # Calculate area
   area <- sf::st_area(geometry)
    # Create a tibble with the results
   cbind(tibble::tibble(
      group_id = group_labels[group_id],
      level = levels,
      h = h_val,
      area = area), geometry)
  }

  # now cast the results to an sf object
  kde_results <- sf::st_as_sf(kde_results, crs = sf::st_crs(x))
  # add a method attribute
  attr(kde_results, "hr_method") <- c("kde")

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    kde_results <- kde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x), dplyr::all_of("group_id")
      )
  }


  return(kde_results)
}

#' Create kde isopleths at multiple levels for a given group
#'
#' This is the internal function that is called by `tt_hr_kde` to create the
#' kde isopleths
#' at multiple levels for a given group. It is not intended to be called
#' directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param levels A vector of levels for the contour lines
#' @param crs the crs of the coordinates (to use in the geometry)
#' @param grid A list of length 5, with values xmin, ymin,
#' xmax, ymax and res (all in the units of the projection of x).
#' @param h The bandwidth for the kernel density estimation.
#' @param keep_object whether the individual KDE object should be kept. If so,
#' the function returns a list of sf polygons and the kde object.
#' @returns A list of sf polygons representing the kde isopleths at each level
#' @keywords internal

kde_one_group <- function(xy, levels, crs, grid, h, keep_object = FALSE) {
  # Create a kde object
  kde <- MASS::  kde2d(xy[,1],
                       xy[,2],
                       n = round(c((grid$xmax-grid$xmin) / grid$res,
                             (grid$ymax-grid$ymin) / grid$res)),
                       h = h,
                       lims = c(grid$xmin, grid$xmax,
                                grid$ymin, grid$ymax))
  #
  kde_cud <- hr_kde_cud(kde$z)

  # create a list of sf polygons for each level
  kde_polys <- lapply(levels, function(level) {
    # get the contour lines for this level
    contour_lines <- grDevices::contourLines(kde$x, kde$y, kde_cud, level = level)
    # convert to sf polygons
    sf_polys <- lapply(contour_lines, function(line) {
      sf::st_polygon(list(cbind(line$x, line$y)))
    })
    # combine into a single sf multipolygon
    sf::st_combine(sf::st_sfc(sf_polys, crs = crs))
  })
  # create a geometry set with one feature per level
  kde_polys <- sf::st_sfc(do.call(rbind, kde_polys), crs = crs)
  return(kde_polys)
}
