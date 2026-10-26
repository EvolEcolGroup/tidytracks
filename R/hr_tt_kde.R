#' Quantify the home range using kernel density estimation
#'
#' This function estimates the home range of an animal using kernel density
#' estimation (KDE).
#' The home range is estimated for each group in `x`, which can be defined by
#' grouping `x` by one or more variables. If `x` is not grouped, the track ID
#' is used as grouping variable, and the home range is estimated for each track
#' separately.
#'
#' @details Events with an empty geometry (i.e. no location) are ignored.
#'
#' By default, the full UD is returned. If `levels` is set, the
#' isopleths for the specified levels are returned instead, along with their
#' area. This option is useful to reduce memory use, but has the drawback that
#' the full UD is not returned, which can be useful for some applications (e.g.
#' to compute overlap between home ranges). If `levels` is set, the area of the
#' isopleths is computed using `sf::st_area()`, which returns the area in the
#' units of the projection of `x` (e.g. m^2 for a UTM projection), or in m^2 if
#' `x` is unprojected (longitude/latitude). Note, however, that for unprojected
#' data the kernel is computed in degrees, so the bandwidth and the shape of the
#' UD are distorted (increasingly so away from the equator); it is recommended
#' to project `x` to an appropriate projection before using this function.
#'
#' @param x A move2 object; if explicitly grouped, the home range is estimated
#'   for each group, combining all tracks within each group. Otherwise, the
#'   track id is used as grouping variable. Every group must have events, so
#'   groupings with empty groups (e.g. from grouping by a factor with unused
#'   levels with `.drop = FALSE`) give an error.
#' @param h The bandwidth for the kernel density estimation. Either a number,
#'   a vector with one value per group, or "h_ref_indiv" for using the
#'   reference bandwidth for each individual, or "h_ref_mean" for using the mean
#'   bandwidth for all individuals (the default). The reference bandwidth cannot
#'   be computed for groups with fewer than two distinct locations: such groups
#'   are left out of the mean for "h_ref_mean", and cause an error with
#'   "h_ref_indiv".
#' @param bbox A named vector of four elements (`xmin`, `ymin`, `xmax`, `ymax`)
#'   defining a grid shared by all groups, or a list of one such vector per
#'   group. If `NULL`, a shared grid is created from the extent of all points in
#'   `x`, expanded by 100% of the range on each side.
#' @param res The resolution of the grid (in the units of the projection of x).
#'   Supply one value for a shared resolution or one value per group when
#'   `bbox` contains one grid per group. If `NULL`, each grid is assigned a
#'   resolution that produces approximately 1000 cells.
#'
#'   Per-group values of `h`, `bbox` and `res` are matched to the groups in the
#'   order of [dplyr::group_keys()] (i.e. sorted by the grouping variables),
#'   not in the order in which the groups appear in `x`.
#' @param levels A vector of levels for the isopleths (i.e. contour lines), as
#'   numbers between 0 and 1. If set to NULL (the default), the full utilisation
#'   distribution is returned; otherwise just the isopleths are returned. It is
#'   possible to specify more than two levels, e.g.  `c(0.5, 0.95)` corresponds
#'   to the 50% and 95% home ranges.
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#' NULL, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
#' [hr_tt_ud_iso()]), with columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`
#' - `method`: the method used to estimate the home range (`"kde"`)
#' - `h`: the bandwidth used for the KDE
#' - `xmin`, `ymin`, `xmax`, `ymax`: the bounding box used for the KDE
#' - `res`: the resolution used for the KDE
#' If `levels` is NULL:
#' - `ud`: the full utilisation distribution is returned as a list-column of
#'   `terra::SpatRaster` objects
#' Else, if `levels` is not NULL, there is one row per group and level, and
#' the following columns are added:
#' - `level`: the level of the isopleth
#' - `area`: the area of the home range at this level (in the units
#'   of the projection of `x`, e.g. m^2 for a UTM projection, or in m^2 for
#'   unprojected data)
#' - `geometry`:  an `sfc` column containing the multipolygons representing
#'   the isopleth for the appropriate level
#'
#' @export
#' @examples
#' example_kde <- hr_tt_kde(example_tt)
#' example_kde
#' library(ggplot2)
#' autoplot(example_kde)
#' # compute the isopleths for the 50% and 95% home range
#' example_iso <- hr_tt_kde(example_tt, levels = c(0.5, 0.95))
#' ggplot(example_iso) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
#'
hr_tt_kde <- function(
  x,
  h = "h_ref_mean",
  bbox = NULL,
  res = NULL,
  levels = NULL
) {
  # if x is not grouped, use the track ID column as grouping variable
  if (!inherits(x, "grouped_df")) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  # per-group values (h, bbox and res) are matched to the groups by their
  # position in the group keys, which must therefore all be estimated
  check_no_empty_groups(x) # nolint: object_usage_linter.

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
  # events with an empty geometry have no location to contribute to the KDE
  located <- stats::complete.cases(xy)
  xy <- xy[located, , drop = FALSE]
  group_index <- group_index[located]
  if (!all(group_unique %in% group_index)) {
    stop("each group must contain at least one event with a location")
  }
  # check h
  if (!is.numeric(h)) {
    h <- match.arg(
      h,
      c(
        "h_ref_mean",
        "h_ref_indiv"
      )
    )
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
  if (any(!is.finite(h) | h <= 0)) {
    stop(
      "h must be a positive number for every group; the reference bandwidth ",
      "cannot be computed for groups with fewer than two distinct locations ",
      "(use h = \"h_ref_mean\" or a numeric h instead)"
    )
  }

  # Create a shared grid by default.
  if (is.null(bbox)) {
    bbox <- sf::st_bbox(x)
    bbox <- expand_kde_bbox(bbox)
    bbox <- rep(list(bbox), length(group_unique))
  } else if (is_kde_bbox(bbox)) {
    bbox <- rep(
      list(normalise_kde_bbox(bbox)),
      length(group_unique)
    )
  } else {
    if (!is.list(bbox) || length(bbox) != length(group_unique)) {
      stop(
        "bbox must be a named vector of length 4 or a list with one ",
        "named vector per group"
      )
    }
    bbox <- lapply(bbox, normalise_kde_bbox)
  }

  if (is.null(res)) {
    res <- vapply(bbox, kde_resolution, numeric(1))
  } else if (
    !is.numeric(res) ||
      !(length(res) %in% c(1, length(group_unique)))
  ) {
    stop(
      "res must be a single numeric value or a vector with one value per group"
    )
  }
  if (length(res) == 1) {
    res <- rep(res, length(group_unique))
  }
  if (any(!is.finite(res) | res <= 0)) {
    stop("res must contain finite, positive values")
  }
  bbox <- Map(align_kde_bbox, bbox, res)
  group_id <- NULL # hack to avoid it being flagged as global in checks
  kde_results <- foreach::foreach(
    group_id = group_unique,
    .combine = rbind # dplyr::bind_rows
  ) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, , drop = FALSE]
    h_val <- h[group_id]
    bbox_val <- bbox[[group_id]]
    res_val <- res[group_id]
    # Create kernel for each level
    kde <- kde_one_group(
      xy_sub,
      crs = sf::st_crs(x),
      bbox = bbox_val,
      res = res_val,
      h = h_val,
      id = group_id
    )
    # row for the table to integrate the results
    res_tbl <- tibble::tibble(
      group_id = group_labels[group_id],
      method = "kde",
      h = h_val,
      xmin = bbox_val[["xmin"]],
      ymin = bbox_val[["ymin"]],
      xmax = bbox_val[["xmax"]],
      ymax = bbox_val[["ymax"]],
      res = res_val
    )

    # if returning the full kde object, we simply add it to the kde column
    # add the kde to the tibble as a list column
    res_tbl$ud <- list(kde)
    names(res_tbl$ud) <- group_labels[group_id]
    # add a class to the tibble
    class(res_tbl) <- c("hr_tt_ud_tbl", class(res_tbl))
    res_tbl
  }

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    kde_results <- kde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x),
        dplyr::all_of("group_id")
      )
  }

  # the isopleths are computed once the UDs of the groups are combined (and
  # the group_id column renamed): combining and renaming sf tables of
  # isopleths would leave their attributes (e.g. agr) with the old names
  if (!is.null(levels)) {
    kde_results <- hr_tt_ud_iso(kde_results, levels)
  }

  return(kde_results)
}

is_kde_bbox <- function(x) {
  length(x) == 4 &&
    all(c("xmin", "ymin", "xmax", "ymax") %in% names(x))
}

normalise_kde_bbox <- function(bbox) {
  if (!is_kde_bbox(bbox)) {
    stop("each bbox must be a named vector of length 4")
  }
  bbox <- unlist(bbox, use.names = TRUE)
  bbox <- bbox[c("xmin", "ymin", "xmax", "ymax")]
  if (
    !is.numeric(bbox) ||
      any(!is.finite(bbox)) ||
      bbox[["xmin"]] >= bbox[["xmax"]] ||
      bbox[["ymin"]] >= bbox[["ymax"]]
  ) {
    stop("each bbox must contain finite xmin < xmax and ymin < ymax values")
  }
  bbox
}

expand_kde_bbox <- function(bbox) {
  bbox <- normalise_kde_bbox(bbox)
  extend_x <- bbox[["xmax"]] - bbox[["xmin"]]
  extend_y <- bbox[["ymax"]] - bbox[["ymin"]]

  bbox["xmin"] <- bbox[["xmin"]] - extend_x
  bbox["ymin"] <- bbox[["ymin"]] - extend_y
  bbox["xmax"] <- bbox[["xmax"]] + extend_x
  bbox["ymax"] <- bbox[["ymax"]] + extend_y
  bbox
}

kde_resolution <- function(bbox) {
  sqrt(
    (bbox[["xmax"]] - bbox[["xmin"]]) *
      (bbox[["ymax"]] - bbox[["ymin"]]) /
      1000
  )
}

align_kde_bbox <- function(bbox, res) {
  bbox["xmax"] <- bbox[["xmin"]] +
    ceiling((bbox[["xmax"]] - bbox[["xmin"]]) / res) * res
  bbox["ymax"] <- bbox[["ymin"]] +
    ceiling((bbox[["ymax"]] - bbox[["ymin"]]) / res) * res
  bbox
}


#' Compute the kde for a given group
#'
#' This is the internal function that is called by `hr_tt_kde` to compute the
#' kde for a given group. It is not intended to be called directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param crs the crs of the coordinates (to use in the geometry)
#' @param bbox A named vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid over which to compute the KDE.
#' @param res The resolution of the grid (in the units of the projection of x).
#' @param h The bandwidth for the kernel density estimation.
#' @param id The identifier for the group (used in raster metadata).
#' @return A `terra::SpatRaster`.
#' @keywords internal
#' @noRd
kde_one_group <- function(xy, crs, bbox, res, h, id) {
  kde <- MASS::kde2d(
    xy[, 1],
    xy[, 2],
    n = round(c(
      (bbox[["xmax"]] - bbox[["xmin"]]) / res,
      (bbox[["ymax"]] - bbox[["ymin"]]) / res
    )),
    # note that MASS needs h multiplied by 4 to be comparable with other kde
    # approaches (e.g. adehabitatHR or KernSmooth)
    h = h * 4,
    lims = c(
      # note that the limits in MASS refer to the centroids of the cells, so we
      # need to add res/2 to the min and subtract res/2 from the max
      bbox[["xmin"]] + res / 2,
      bbox[["xmax"]] - res / 2,
      bbox[["ymin"]] + res / 2,
      bbox[["ymax"]] - res / 2
    )
  )

  # estimate the sum of the density
  sum_density <- sum(kde$z, na.rm = TRUE)

  # standardise the density values to sum to 1
  kde$z <- kde$z / sum_density

  # turn it into a raster (flipping the x axis appropriately)
  kde$z <- t(kde$z)
  r <- terra::rast(
    kde$z[rev(seq_len(nrow(kde$z))), ],
    crs = crs$wkt,
    extent = terra::ext(
      bbox[["xmin"]],
      bbox[["xmax"]],
      bbox[["ymin"]],
      bbox[["ymax"]]
    )
  )
  names(r) <- "ud"
  terra::metags(r) <- c(
    paste0("id = ", id),
    "method = kde",
    paste0("h = ", h),
    paste0("density_sum = ", sum_density)
  )

  r
}

# deprecated function for backward compatibility
#' @name hr_tt_kde
#' @export
hr_kde <- function(
  x,
  h = "h_ref_mean",
  bbox = NULL,
  res = NULL,
  levels = NULL
) {
  warning("hr_kde is deprecated. Please use hr_tt_kde instead.", call. = FALSE)
  hr_tt_kde(
    x = x,
    h = h,
    bbox = bbox,
    res = res,
    levels = levels
  )
}
