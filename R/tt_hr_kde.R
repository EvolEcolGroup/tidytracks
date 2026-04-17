#' Quantify the home range using kernel density estimation
#'
#' This function estimates the home range of an animal using kernel density
#' estimation (KDE). #' The home range is estimated for each group in `x`, which
#' can be defined by grouping `x` by one or more variables. If `x` is not
#' grouped, the track ID is used as grouping variable, and the home range is
#' estimated for each track separately.
#'
#' @details By default, the full UD is returned. If `levels` is set, the
#' isopleths for the specified levels are returned instead, along with their
#' area. This option is useful to reduce memory use, but has the drawback that
#' the full UD is not returned, which can be useful for some applications (e.g.
#' to compute overlap between home ranges). If `levels` is set, the area of the
#' isopleths is computed using `sf::st_area()`, which returns the area in the
#' units of the projection of `x` (e.g. m^2 for a UTM projection). If `x` is
#' unprojected, the area is computed in degrees^2, which is not a meaningful
#' unit for area. In this case, it is recommended to project `x` to an
#' appropriate projection before using this function. 
#'
#' @param x A move2 object; if explicitely grouped, the home range is estimated
#'   for each group, combining all tracks within each group. Otherwise, the
#'   track id is used as grouping variable.
#' @param h The bandwidth for the kernel density estimation. Either a number, or
#'   "h_ref_indiv" for using the reference bandwidth for each individual, or
#'   "h_ref_mean" for using the mean bandwidth for all individuals (the
#'   default).
#' @param bbox a name vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid over which to compute the KDE. If NULL, the
#'   extent is taken by combining all points in `x` (expanded by 10%).
#' @param res The resolution of the grid (in the units of the projection of x).
#'   If NULL, res is set to obtained ~ 1000 cells.
#' @param levels A vector of levels for the isopleths (i.e. contour lines), as
#'   numbers between 0 and 1.If set to NULL (the defaul), the full utilisation
#'   distribution is returned; otherwise just the isopleths are returned. It is
#'   possible to specify more than two levels, e.g.  `c(0.5, 0.95)` corresponds
#'   to the 50% and 95% home ranges.
#' @returns Either a `tibble`, or, if `levels` is not NULL, an `sf` tibble , 
#' with columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`
#' - `level`: the level of the isopleth
#' - `h`: the bandwidth used for the KDE
#' - `xmin`, `ymin`, `xmax`, `ymax`: the bounding box used for the KDE
#' - `res`: the resolution used for the KDE
#' If `levels` is NULL:
#' - `kde`: the full KDE object is returned in a list column
#' Else, if `levels` is not NULL, the following columns are added:
#' - `area`: the area of the home range at this level (in the units
#'   of the projection of `x`, e.g. m^2 for a UTM projection)
#'  - `geometry`:  an `sfc` column containing the multipolygons representing
#'   the isopleth for the appropriate level
#'
#' @export

tt_hr_kde <- function(x, h = "h_ref_mean", bbox = NULL,
                      res = NULL, levels = NULL) {
  # if x is not grouped, used the track ID as grouping variable
  if (!inherits(x, "grouped_df")) {
    x <- dplyr::group_by(x, event_track_id(x))
  }

  # Check if levels are valid
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from small to big
  levels <- sort(levels)

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
      (bbox[["ymax"]] - bbox[["ymin"]]) / 1000)
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
    # Create kernel for each level
    kde <- kde_one_group(xy_sub, levels,
      crs = sf::st_crs(x),
      bbox = bbox,
      res = res,
      h = h_val,
      id = group_id
    )
    # row for the table to integrate the results
    res_tbl <- tibble::tibble(
      group_id = group_labels[group_id],
      h = h_val,
      xmin = bbox["xmin"],
      ymin = bbox["ymin"],
      xmax = bbox["xmax"],
      ymax = bbox["ymax"],
      res = res
    )

    # if returning the full kde object, we simply add it to the kde column
      # add the kde to the tibble as a list column
      res_tbl$ud <- PackedSpatRaster_list(kde)
      names(res_tbl$ud) <- group_labels[group_id]
      # add a class to the tibble
      class(res_tbl) <- c("hr_ud_tbl", class(res_tbl))
    if (!is.null(levels)) {
      res_tbl <- hr_ud_iso(res_tbl, levels)
    }
    res_tbl
  }
  # # change class of ud column to PackedSpatRaster_list
  # names(kde_results$ud) <- group_labels
  # kde_results$ud <- as_PackedSpatRaster_list(kde_results$ud)
  
  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    kde_results <- kde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x), dplyr::all_of("group_id")
      )
  }
  
  return(kde_results)
}


#' Compute the kde for a given group
#'
#' This is the internal function that is called by `tt_hr_kde` to compute the
#' kde for a given group. It is not intended to be called directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param crs the crs of the coordinates (to use in the geometry)
#' @param bbox A named vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid over which to compute the KDE.
#' @param res The resolution of the grid (in the units of the projection of x).
#' @param h The bandwidth for the kernel density estimation.
#' @return A PackedSpatRaster.
#' @keywords internal
kde_one_group <- function(xy, levels, crs, bbox, res, h, id) {
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
      # note that the limits in MASS refer to the centroids of the cells, so we
      # need to add res/2 to the min and subtract res/2 from the max
      bbox$xmin+res/2, bbox$xmax-res/2,
      bbox$ymin+res/2, bbox$ymax-res/2
    )
  )
  
  # estimate the sum of the density
  sum_density <- sum(kde$z, na.rm = TRUE)
  
  # standardise the density values to sum to 1
  kde$z <- kde$z / sum_density
  
  # turn it into a raster (flipping the x axis appropriately)
  kde$z <- t(kde$z)
  r <- terra::rast(kde$z[nrow(kde$z):1,],
                   crs = crs$wkt,
                   extent =terra::ext(bbox$xmin, bbox$xmax, 
                                      bbox$ymin, bbox$ymax)
  )
  names(r) <- "ud"
  terra::metags(r) <- c(paste0("id = ", id),"method = kde", paste0("h = ",h),
                        paste0("density_sum" = sum_density))

  # return it wrapped (so that it can be put in a list)
  return(terra::wrap(r))
}

