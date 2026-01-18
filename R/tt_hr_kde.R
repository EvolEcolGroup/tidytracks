#' Quantify the home range using kernel density estimation
#'
#' This function estimates the home range of an animal using kernel density
#' estimation (KDE).
#'
#' @param x A grouped move2 object
#' @param h The bandwidth for the kernel density estimation. Either a number, or
#'   "h_ref_indiv" for using the reference bandwidth for each individual, or
#'   "h_ref_mean" for using the mean bandwidth for all individuals (the
#'   default).
#' @param bbox a name vector of four elements: xmin, ymin, xmax, ymax to define the
#'  bounding box of the grid over which to compute the KDE. If NULL, the
#'  extent is taken by combining all points in `x` (expanded by 10%).
#' @param res The resolution of the grid (in the units of the projection of x).
#'   If NULL, res is set to obtained ~ 1000 cells.
#' @param levels A vector of levels for the contour lines. The default is
#'   `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges. If set
#'   to NULL, the full kde object is returned (useful for debugging)
#' @returns An `sf` tibble , with columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#' multiple variables, this column is named `group_id`): the ids from
#' the grouping of `x`
#' - `level`: the level of the isopleth
#' - `h`: the bandwidth used for the KDE
#' - `area`: the area of the home range at this level (in the units
#'  of the projection of `x`, e.g. m^2 for a UTM projection)
#'  - `geometry`:  an `sfc` column containing the multipolygons representing
#'  the isopleth for the appropriate level
#'
#'   If `levels` is NULL, a standard tibble is returned with columns:
#'   `group_id`, `h`, and `kde`.
#'
#'   The bbox and res used are stored as attributes of the returned object.
#'
#' @export

tt_hr_kde <- function(x, h = "h_ref_mean", bbox = NULL,
                      res = NULL, levels = c(0.5, 0.95)) {
  # Check if x is a grouped move2 object
  if (!inherits(x, "move2") || !inherits(x, "grouped_df")) {
    stop("x must be a grouped move2 object")
  }

  # Check if levels are valid
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)

  # get the group indices
  group_index <- dplyr::group_indices(x)
  group_unique <- unique(group_index)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  # extract coordinates
  xy <- sf::st_coordinates(x)
  # check h
  if (!is.numeric(h)) {
    h <- match.arg(h, c(
      "h_ref_mean", "h_ref_indiv"
    ))
    h_fun <- get(h) # assign the function to h_fun
    h <- h_fun(xy, group_index) # compute h
  }
  if (length(h) == 1) {
    h <- rep(h, length(group_unique))
  } else if (length(h) != length(group_unique)) {
    stop(
      "h must be a single value or a vector of the same length as ",
      "the number of groups in x"
    )
  }

  # Check if grid is provided
  if (is.null(bbox)) {
    # get extend of x, which is an sf object
    bbox <- sf::st_bbox(x)
    # extend the grid by a fixed factor
    # TODO compare to amt (extending by 50%), adehabitatHR (extending by 1)
    # and track2kba (extending by 0.05 or h*2000, whichever is larger))
    extend_x <- (bbox$xmax - bbox$xmin) * 1
    extend_y <- (bbox$ymax - bbox$ymin) * 1

    bbox["xmin"] <- bbox$xmin - extend_x
    bbox["ymin"] <- bbox$ymin - extend_y
    bbox["xmax"] <- bbox$xmax + extend_x
    bbox["ymax"] <- bbox$ymax + extend_y
  }
  # check that bbox is a vector of four correctly named elements
  if (length(bbox) != 4 ||
    !all(c("xmin", "ymin", "xmax", "ymax")
    %in% names(bbox))) {
    stop("bbox must be a named vector of length 4")
  }


  if (is.null(res)) {
    # set resolution to get a 1000 cells
    res <- sqrt((bbox[["xmax"]] - bbox[["xmin"]]) *
      (bbox[["ymax"]] - bbox[["ymin"]]) / 1500)
  }

  # update the max to be an exact multiple of res
  bbox["xmax"] <- bbox$xmin +
    ceiling((bbox$xmax - bbox$xmin) / res) * res
  bbox["ymax"] <- bbox$ymin +
    ceiling((bbox$ymax - bbox$ymin) / res) * res


  group_id <- NULL # hack to avoid it being flagged as global in checks
  kde_results <- foreach::foreach(
    group_id = group_unique,
    .combine = rbind # dplyr::bind_rows
  ) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, ]
    h_val <- h[group_id]
    # prepare results table
    res_tbl <- tibble::tibble(
      group_id = group_labels[group_id],
      level = levels,
      h = h_val
    )
    # estimate the UD surface
    ud_surface <- kde_surface_one_group(xy_sub,
      bbox = bbox,
      res = res,
      h = h_val
    )


    # if returning the full kde object, we simply add it to the kde column
    if (is.null(levels)) {
      res_tbl$kde <- list(kde = ud_surface)
      res_tbl
    } else { # with multiple levels, we create the area and geometry columns
      # get the isopleths
      isopleths_set <- kde_isopleths_one_group(
        ud_surface,
        levels,
        crs = sf::st_crs(x),
        bbox = bbox,
        res = res
      )
      # Calculate area
      area <- sf::st_area(isopleths_set)
      # Create a tibble with the results
      cbind(res_tbl, area, isopleths_set)
    }
  }

  # if levels is not  null, we convert to sf
  if (!is.null(levels)) {
    # now cast the results to an sf object
    kde_results <- sf::st_as_sf(kde_results, crs = sf::st_crs(x))
  }
  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    kde_results <- kde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x), dplyr::all_of("group_id")
      )
  }

  # add a method attribute
  attr(kde_results, "hr_method") <- c("kde")
  attr(kde_results, "bbox") <- bbox
  attr(kde_results, "res") <- res

  return(kde_results)
}

#' Estimate the KDE surface for a given group
#'
#' This is the internal function that is called by `tt_hr_kde` to estimate the
#' KDE surface for a given group. It is not intended to be called directly by
#' the user.
#' @param xy a matrix of coordinates
#' @param bbox A list with xmin, ymin, xmax, ymax defining the bounding box
#' @param res The resolution of the grid
#' @param h The bandwidth for the kernel density estimation.
#' @returns The KDE representing the cumulative utilisation
#' distribution (cud)
#' @keywords internal

kde_surface_one_group <- function(xy, bbox, res, h) {
  # Create a kde object
  kde <- MASS::kde2d(xy[, 1],
    xy[, 2],
    n = round(c(
      (bbox$xmax - bbox$xmin) / res,
      (bbox$ymax - bbox$ymin) / res
    )),
    # note that MASS needs h multiplied by 4 to be comparable with other kde
    # approaches (e.g. adehabitatHR or KernSmooth)
    h = h * 4,
    lims = c(
      bbox$xmin, bbox$xmax,
      bbox$ymin, bbox$ymax
    )
  )
  return(kde)
}


#' Create kde isopleths at multiple levels for a given group
#'
#' This is the internal function that is called by `tt_hr_kde` to create the kde
#' isopleths at multiple levels for a given group. It is not intended to be
#' called directly by the user.
#' @param kde a kde object as returned by `kde_surface_one_group`
#' @param levels A vector of levels for the contour lines
#' @param crs the crs of the coordinates (to use in the geometry)
#' @param bbox A list with xmin, ymin, xmax, ymax defining the bounding box
#' @param res The resolution of the grid
#' @returns A list of sf polygons representing the kde isopleths at each level
#' @keywords internal
#'

kde_isopleths_one_group <- function(kde, levels, crs, bbox, res) {
  # compute the cumulative utilisation distribution
  kde_cud <- hr_kde_cud(kde$z)

  # create a list of sf polygons for each level
  kde_polys <- lapply(levels, function(level) {
    # get the contour lines for this level
    contour_lines <- grDevices::contourLines(kde$x, kde$y, kde_cud,
      level = level
    )
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
