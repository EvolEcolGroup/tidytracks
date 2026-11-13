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
#' The UD is estimated on a grid of cells, with one of two methods:
#' - `"exact"` evaluates the kernel of every location at the centre of every
#'   cell (with [MASS::kde2d()]), so the time it takes grows with the number
#'   of locations times the number of cells.
#' - `"binned"` (the default) first bins the locations onto the grid, i.e.
#'   splits each location between the four cells whose centres surround it,
#'   in proportion to how close it is to each of them (linear binning, as in
#'   [KernSmooth::bkde2D()]), and then smooths the bin counts with the
#'   kernel. As the Gaussian kernel is separable, the smoothing is computed
#'   along one axis of the grid and then along the other, over the cells
#'   within reach of the kernel only, so the time it takes grows with the
#'   number of cells times the width of the kernel (in cells), whatever the
#'   number of locations: it is much faster than the exact method, except
#'   for groups with only a few locations, for which both are fast. Binning
#'   moves each location by less than a cell, so the UD is very close to the
#'   exact one when the bandwidth spans several cells. The kernel is
#'   truncated at 3.4 bandwidths from each location, beyond which it is
#'   negligible.
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
#'   order in which they are returned: the order of the tracks in the metadata
#'   (see [show_meta()]) if `x` is not grouped, or else the order of
#'   [dplyr::group_keys()] (i.e. sorted by the grouping variables), not the
#'   order in which the groups appear in `x`.
#' @param levels A vector of levels for the isopleths (i.e. contour lines), as
#'   numbers between 0 and 1. If set to NULL (the default), the full utilisation
#'   distribution is returned; otherwise just the isopleths are returned. It is
#'   possible to specify more than two levels, e.g.  `c(0.5, 0.95)` corresponds
#'   to the 50% and 95% home ranges.
#' @param method The method used to estimate the UD on the grid: `"binned"`
#'   (the default), which bins the locations onto the grid before smoothing
#'   them, or `"exact"`, which evaluates the kernel of every location at every
#'   cell. See Details.
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#' NULL, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
#' [hr_tt_ud_iso()]), with columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`, in the order of the tracks in the metadata if `x` is not
#'   grouped, or else in the order of [dplyr::group_keys()]
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
#' # the same isopleths, evaluating the kernel of every location at every cell
#' example_iso_exact <- hr_tt_kde(
#'   example_tt,
#'   levels = c(0.5, 0.95),
#'   method = "exact"
#' )
#'
hr_tt_kde <- function(
  x,
  h = "h_ref_mean",
  bbox = NULL,
  res = NULL,
  levels = NULL,
  method = c("binned", "exact")
) {
  method <- match.arg(method)
  # if x is not grouped, use the track ID column as grouping variable
  by_track <- !inherits(x, "grouped_df")
  if (by_track) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  # per-group values (h, bbox and res) are matched to the groups by their
  # position in the order in which they are returned, so every group listed
  # in the group keys must be estimated
  check_no_empty_groups(x) # nolint: object_usage_linter.

  # Check if levels are valid
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)

  # get the group indices; the groups are estimated (and returned) in the
  # order of the tracks in the metadata if x was not grouped, or else in the
  # order of their keys, as for the other hr_tt_* functions, rather than in
  # the order in which they appear in x: they are numbered in that order
  group_order <- hr_group_order(x, by_track) # nolint: object_usage_linter.
  group_index <- match(dplyr::group_indices(x), group_order)
  group_unique <- seq_along(group_order)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  group_labels <- group_labels[group_order]
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

  # the function that estimates the UD of a group on its grid, with the
  # chosen method (both return the UD in the same layout)
  kde_density <- switch(
    method,
    exact = kde_density_exact,
    binned = kde_density_binned
  )
  # The binned kernel only extends to the cells whose centres are within
  # binned_kde_reach bandwidths of each grid point: if that is less than a
  # cell, the kernel does not smooth the binned locations at all, so the UD
  # is just the binned locations. Warn once for all the groups, rather than
  # once per group.
  if (method == "binned") {
    too_narrow <- binned_kde_reach * h < res
    if (any(too_narrow)) {
      warning(
        "the bandwidth (h) of ", sum(too_narrow), " group(s) is too small ",
        "for the resolution of the grid (h < res / ", binned_kde_reach, "), ",
        "so their binned UD is just their binned locations; use a smaller ",
        "res",
        call. = FALSE
      )
    }
  }

  # Groups usually share a grid (the default), and setting up a grid (its
  # raster, the CRS of its isopleths, the coordinates of its cells) takes
  # longer than the KDE of a small group, so each distinct grid is set up only
  # once
  crs_x <- sf::st_crs(x)
  grid_key <- vapply(
    seq_along(bbox),
    function(i) paste(c(bbox[[i]], res[i]), collapse = " "),
    character(1)
  )
  grids <- lapply(
    match(unique(grid_key), grid_key),
    function(i) {
      kde_grid(bbox[[i]], res[i], crs_x, isopleths = !is.null(levels))
    }
  )
  grid_of_group <- match(grid_key, unique(grid_key))
  # the levels of the isopleths, from the smallest to the largest (as in
  # hr_tt_ud_iso())
  iso_levels <- sort(levels)

  group_id <- NULL # hack to avoid it being flagged as global in checks
  uds <- foreach::foreach(group_id = group_unique) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, , drop = FALSE]
    grid <- grids[[grid_of_group[group_id]]]
    # Compute the UD, with the chosen method
    density <- kde_density(
      xy_sub,
      bbox = bbox[[group_id]],
      res = res[group_id],
      h = h[group_id]
    )
    # if the kernels of the locations do not reach the grid, the density is 0
    # on all its cells, and cannot be standardised (it would be NaN)
    if (!isTRUE(density$density_sum > 0)) {
      stop(
        "the UD of group ", group_labels[group_id], " is 0 on the whole ",
        "grid, as its locations are too far from it; use a bbox that ",
        "covers them",
        call. = FALSE
      )
    }
    if (is.null(levels)) {
      # return the full UD, as a raster
      kde_raster(density, grid, h = h[group_id], id = group_id)
    } else {
      # return its isopleths (the UD itself is not needed, so no raster is
      # built for it); the UD is laid out as cud_isopleths() expects it
      cud <- hr_tt_cud(density$ud) # nolint: object_usage_linter.
      iso <- cud_isopleths( # nolint: object_usage_linter.
        cud,
        x = grid$x,
        y = grid$y,
        res = grid$res,
        levels = iso_levels,
        ops_crs = if (grid$longlat) grid$iso_crs else sf::NA_crs_,
        cud_raster = function() {
          terra::setValues(
            grid$template,
            xy_matrix_values(cud) # nolint: object_usage_linter.
          )
        }
      )
      iso_sf(iso, grid$iso_crs) # nolint: object_usage_linter.
    }
  }

  # one row per group
  kde_results <- tibble::tibble(
    group_id = group_labels[group_unique],
    method = "kde",
    h = h[group_unique],
    xmin = vapply(bbox[group_unique], function(b) b[["xmin"]], numeric(1)),
    ymin = vapply(bbox[group_unique], function(b) b[["ymin"]], numeric(1)),
    xmax = vapply(bbox[group_unique], function(b) b[["xmax"]], numeric(1)),
    ymax = vapply(bbox[group_unique], function(b) b[["ymax"]], numeric(1)),
    res = res[group_unique]
  )
  # if there was a single grouping variable, rename the group_id column (before
  # the isopleths are added: renaming an sf table of isopleths would leave its
  # attributes (e.g. agr) with the old names)
  if (length(dplyr::group_vars(x)) == 1) {
    kde_results <- kde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x),
        dplyr::all_of("group_id")
      )
  }
  if (is.null(levels)) {
    # the full UDs, as a list column of rasters
    kde_results$ud <- stats::setNames(uds, group_labels[group_unique])
    class(kde_results) <- c("hr_tt_ud_tbl", class(kde_results))
  } else {
    # one row per group and level, with the isopleths and their areas
    kde_results <- isopleth_table( # nolint: object_usage_linter.
      kde_results,
      uds
    )
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


#' Set up a grid for the KDE
#'
#' Internal function called by `hr_tt_kde` for each distinct grid: it creates
#' an empty raster for the grid (from which the rasters of the UDs are made,
#' which is faster than creating each of them from scratch), and works out
#' the CRS of the isopleths and the coordinates of the cells, all of which
#' are the same for all the groups that share the grid.
#'
#' @param bbox A named vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid.
#' @param res The resolution of the grid (in the units of the projection of x).
#' @param crs the crs of the coordinates.
#' @param isopleths whether isopleths will be computed on the grid.
#' @returns A list with `template` (an empty `terra::SpatRaster`, with a
#'   layer named `"ud"`) and, if
#'   `isopleths` is `TRUE`, `iso_crs` (the CRS of the isopleths, as obtained
#'   from the raster), `longlat` (whether that CRS is in longitude/latitude),
#'   `x` and `y` (the coordinates of the centres of the columns, and of the
#'   rows from south to north), and `res` (the size of the cells along x and
#'   along y).
#' @keywords internal
#' @noRd
kde_grid <- function(bbox, res, crs, isopleths) {
  n <- round(c(
    (bbox[["xmax"]] - bbox[["xmin"]]) / res,
    (bbox[["ymax"]] - bbox[["ymin"]]) / res
  ))
  template <- terra::rast(
    nrows = n[2],
    ncols = n[1],
    xmin = bbox[["xmin"]],
    xmax = bbox[["xmax"]],
    ymin = bbox[["ymin"]],
    ymax = bbox[["ymax"]],
    crs = crs$wkt
  )
  # named once here, rather than each of the rasters of the UDs made from it
  names(template) <- "ud"
  if (!isopleths) {
    return(list(template = template))
  }
  iso_crs <- sf::st_crs(terra::crs(template))
  list(
    template = template,
    iso_crs = iso_crs,
    longlat = isTRUE(sf::st_is_longlat(iso_crs)),
    x = terra::xFromCol(template, seq_len(n[1])),
    y = terra::yFromRow(template, rev(seq_len(n[2]))),
    res = terra::res(template)
  )
}

#' Compute the exact kde for a given group
#'
#' This is the internal function that is called by `hr_tt_kde` to compute the
#' kde for a given group with `method = "exact"`: the kernel of every location
#' is evaluated at the centre of every cell. It is not intended to be called
#' directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param bbox A named vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid over which to compute the KDE.
#' @param res The resolution of the grid (in the units of the projection of x).
#' @param h The bandwidth for the kernel density estimation.
#' @returns A list with `ud` (a matrix of densities that sum to 1, with one
#'   row per column of cells, from west to east, and one column per row of
#'   cells, from south to north) and `density_sum` (the sum of the densities
#'   before standardisation), as from `kde_ud_standardise()`.
#' @keywords internal
#' @noRd
kde_density_exact <- function(xy, bbox, res, h) {
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

  # standardise the density (kde2d() already divides it by the number of
  # locations)
  kde_ud_standardise(kde$z)
}

# The binned kernel is truncated at this many bandwidths from its centre (as
# in KernSmooth::bkde2D(), whose constant tau it is): beyond it, the density
# of a Gaussian kernel is less than 0.31% of its peak
binned_kde_reach <- 3.4

#' Compute the binned kde for a given group
#'
#' This is the internal function that is called by `hr_tt_kde` to compute the
#' kde for a given group with `method = "binned"`. It follows
#' `kde_density_exact()`, but, as `KernSmooth::bkde2D()` (Wand 1994), it
#' first bins the locations onto the grid (linear binning: each location is
#' split between the four grid points that surround it, in proportion to how
#' close it is to each of them), and then smooths the bin counts with the
#' kernel (a discrete convolution). Unlike `KernSmooth::bkde2D()`, which
#' computes the convolution with fast Fourier transforms, it computes it
#' directly, along x and then along y (with `kde_convolve_cpp()`): the
#' Gaussian kernel is separable (the kernel in 2D is the product of a kernel
#' along x and one along y), so this gives the same convolution. Only the
#' grid points within reach of the (truncated) kernel are visited, and the
#' empty bins are skipped, so its cost is proportional to the number of
#' cells within reach of the locations times the width of the kernel (in
#' cells), however many locations there are. This is several times faster
#' than the FFT of `KernSmooth::bkde2D()`. It is not intended to be called
#' directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param bbox A named vector of four elements: xmin, ymin, xmax, ymax to define
#'   the bounding box of the grid over which to compute the KDE.
#' @param res The resolution of the grid (in the units of the projection of x).
#' @param h The bandwidth for the kernel density estimation.
#' @returns A list with `ud` (a matrix of densities that sum to 1, with one
#'   row per column of cells, from west to east, and one column per row of
#'   cells, from south to north) and `density_sum` (the sum of the densities
#'   before standardisation), as from `kde_density_exact()`.
#' @keywords internal
#' @noRd
kde_density_binned <- function(xy, bbox, res, h) {
  # the number of cells of the grid, along x and along y
  n_cells <- round(c(
    (bbox[["xmax"]] - bbox[["xmin"]]) / res,
    (bbox[["ymax"]] - bbox[["ymin"]]) / res
  ))
  # As in kde_density_exact(), the density is estimated at the centres of the
  # cells, so the locations are binned onto the centres of the cells too,
  # and the kernel is evaluated at whole numbers of cells from them.
  # (amt::hr_kde() instead gives KernSmooth::bkde2D() grid points that go
  # from edge to edge of its raster, which are slightly more than a cell
  # apart, and so stretch the UD by up to half a cell towards the edges of
  # the grid.)
  first_centre <- c(bbox[["xmin"]], bbox[["ymin"]]) + res / 2
  last_centre <- first_centre + (n_cells - 1) * res

  # With kde_density_exact(), the locations outside the grid still add the
  # tails of their kernels to the nearby cells. To keep them, the locations
  # are binned onto a grid of centres extended by whole cells (so that its
  # points stay at the centres of cells) until it covers them; the density is
  # then only estimated at the centres of the cells of the original grid.
  # The kernel is truncated at binned_kde_reach bandwidths, and binning moves
  # each location to grid points less than a cell away, so the grid never
  # needs to be extended by more than that plus one cell: kde_linbin_cpp()
  # moves the locations farther away onto the edge of the extended grid,
  # which is beyond the reach of the kernel from the cells of the grid.
  reach <- ceiling(binned_kde_reach * h / res) + 1
  xy_min <- c(min(xy[, 1]), min(xy[, 2]))
  xy_max <- c(max(xy[, 1]), max(xy[, 2]))
  # the number of grid points to add before the first centre, along x and
  # along y, and after the last centre
  pad_low <- pmin(reach, pmax(0, ceiling((first_centre - xy_min) / res)))
  pad_high <- pmin(reach, pmax(0, ceiling((xy_max - last_centre) / res)))
  n_bins <- n_cells + pad_low + pad_high
  first_bin <- first_centre - pad_low * res

  # the binned counts, with one row per grid point along x and one column per
  # grid point along y
  counts <- kde_linbin_cpp( # nolint: object_usage_linter.
    xy[, 1],
    xy[, 2],
    x0 = first_bin[1],
    y0 = first_bin[2],
    res = res,
    nx = n_bins[1],
    ny = n_bins[2]
  )

  # The 2D kernel is the product of a kernel along x and one along y, so the
  # convolution of the counts with it is a convolution along x followed by a
  # convolution along y, each with the weights of the kernel along its axis.
  # The result is the density at the centre of each cell (rows along x,
  # columns along y, as from MASS::kde2d()), times the number of locations.
  z <- kde_convolve_cpp( # nolint: object_usage_linter.
    counts,
    wx = kde_kernel_weights(n_bins[1], h, res),
    wy = kde_kernel_weights(n_bins[2], h, res),
    ncx = n_cells[1],
    ncy = n_cells[2],
    offx = pad_low[1],
    offy = pad_low[2]
  )

  # standardise the density, as for the exact KDE (dividing its sum by the
  # number of locations, so that it is the same as from kde_density_exact())
  kde_ud_standardise(z, n_locations = nrow(xy))
}

#' Weights of the kernel along one axis of the binned kde
#'
#' Internal function called by `kde_density_binned()`: the weights with which
#' `kde_convolve_cpp()` convolves binned counts with a Gaussian kernel along
#' one axis, i.e. the kernel at 0, 1, ... grid points from its centre. As in
#' `KernSmooth::bkde2D()`, the kernel is truncated at `binned_kde_reach`
#' bandwidths (in whole cells, and at most the size of the grid of binned
#' counts), and its values are rescaled so that, as a discrete density, it
#' integrates to 1 (which makes up for the truncation, and for evaluating it
#' at a few points only when the bandwidth spans few cells).
#'
#' @param n_bins the number of grid points of the binned counts along the
#'   axis.
#' @param h The bandwidth for the kernel density estimation.
#' @param res The resolution of the grid.
#' @returns A numeric vector with the weights of the kernel at 0, 1, ...,
#'   half-width grid points from its centre.
#' @keywords internal
#' @noRd
kde_kernel_weights <- function(n_bins, h, res) {
  # the half-width of the truncated kernel, in cells
  half_width <- min(floor(binned_kde_reach * h / res), n_bins - 1)
  # the kernel (a normal density with standard deviation h) at 0, 1, ...,
  # half_width cells from its centre
  weights <- stats::dnorm(seq(0, half_width) * res / h) / h
  # rescaled so that the kernel over the whole band (both sides of the
  # centre, which is counted once) times the resolution is 1
  weights / (res * (2 * sum(weights) - weights[1]))
}

#' Standardise a kde
#'
#' Internal function called by `kde_density_exact()` and
#' `kde_density_binned()`, which both estimate the density in a matrix with
#' one row per column of cells (from west to east), and one column per row
#' of cells (from south to north). The UD is kept in that layout, which is
#' the one in which `cud_isopleths()` draws its isopleths; `kde_raster()`
#' turns it into a raster.
#'
#' @param z the matrix of densities.
#' @param n_locations the number of locations, if `z` is not yet divided by
#'   it.
#' @returns A list with `ud` (a matrix of densities that sum to 1, laid out as
#'   `z`) and `density_sum` (the sum of the densities, divided by
#'   `n_locations`, before standardisation).
#' @keywords internal
#' @noRd
kde_ud_standardise <- function(z, n_locations = 1) {
  sum_z <- sum(z, na.rm = TRUE)
  list(
    ud = z / sum_z,
    density_sum = sum_z / n_locations
  )
}

#' Turn the kde of a group into a raster
#'
#' @param density the kde, as returned by `kde_density()`.
#' @param grid the grid, as returned by `kde_grid()`.
#' @param h The bandwidth for the kernel density estimation.
#' @param id The identifier for the group (used in raster metadata).
#' @return A `terra::SpatRaster`, with a layer named `"ud"`.
#' @keywords internal
#' @noRd
kde_raster <- function(density, grid, h, id) {
  # the template is already named "ud", and setValues() returns a new raster
  # (leaving the template empty)
  r <- terra::setValues(
    grid$template,
    xy_matrix_values(density$ud) # nolint: object_usage_linter.
  )
  terra::metags(r) <- c(
    paste0("id = ", id),
    "method = kde",
    paste0("h = ", h),
    paste0("density_sum = ", density$density_sum)
  )
  r
}

# deprecated function for backward compatibility
#' @rdname tidytracks-deprecated
#' @export
hr_kde <- function(
  x,
  h = "h_ref_mean",
  bbox = NULL,
  res = NULL,
  levels = NULL,
  method = c("binned", "exact")
) {
  warning("hr_kde is deprecated. Please use hr_tt_kde instead.", call. = FALSE)
  hr_tt_kde(
    x = x,
    h = h,
    bbox = bbox,
    res = res,
    levels = levels,
    method = method
  )
}
