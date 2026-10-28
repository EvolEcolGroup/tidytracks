#' Compute overlap for utilisation distributions
#'
#' This function computes the overlap between pairs of utilisation distributions
#' (UDs) using various methods. If `x` is a `SpatRaster`, it computes the
#' overlap between `x` and `y`. If `x` is an `hr_tt_ud_tbl`, it computes the
#' overlap for all unique pairs of UDs in the table. If `cond_level` is set, it
#' computes the conditional overlap for the specified level, which is the
#' overlap between the UDs estimated within a given isopleth level (e.g. 50%) of
#' the UD, rather than the full UD. This can be useful for comparing the core
#' areas of the UDs.
#'
#' @details When `x` is an `hr_tt_ud_tbl`, each UD is validated, converted to
#'   cell values, and conditionally masked once before all pairwise comparisons
#'   are calculated. This avoids repeated raster reads and
#'   cumulative-distribution calculations for UDs that occur in multiple pairs.
#'
#'   The UDOI is computed as defined by Fieberg & Kochanny (2005), as
#'   \eqn{A_{1,2} \int\int UD_1(x,y) UD_2(x,y) dx dy}, where \eqn{A_{1,2}} is
#'   the area of overlap between the home ranges of the two animals. The home
#'   ranges are the `cond_level` isopleths of the UDs or, if `cond_level` is
#'   `NULL`, their 95% isopleths (as in `adehabitatHR::kerneloverlaphr()`). The
#'   UDOI is 0 for UDs that do not overlap and 1 for two identical, uniformly
#'   distributed UDs, and can be larger than 1 for non-uniform UDs that overlap
#'   considerably. Unlike the other indices, the UDOI of a UD with itself is
#'   therefore not 1, and it is reported on the diagonal of the matrix returned
#'   for a table of UDs.
#'
#'   The isopleths used with `cond_level`, and for the UDOI, must contain at
#'   least one cell of the grid: an error is given if a single cell holds more
#'   than `cond_level` (or, for the UDOI with `cond_level = NULL`, 95%) of a
#'   UD, as can happen on a grid that is coarse relative to the UD.
#' @references Fieberg, J. & Kochanny, C.O. (2005) Quantifying home-range
#'   overlap: the importance of the utilization distribution. Journal of
#'   Wildlife Management, 69, 1346-1359.
#' @param x A SpatRaster of the utilisation distribution (with a layer `ud`), or
#'   a tibble of UDs of class `hr_tt_ud_tbl` (e.g. as created with
#'   [hr_tt_kde()]).
#' @param method A character string specifying the method to use for overlap
#'   calculation. Options are `"ba"` (Bhattacharyya's Affinity), `"vi"` (Volume
#'   of Intersection), `"udoi"` (Utilisation Distribution Overlap Index, see
#'   details), `"earth_mover"` (Earth Mover's Distance) and
#'   `"earth_mover_sinkhorn"` (a fast approximation of the Earth Mover's
#'   Distance). The Earth Mover's Distances are distances, in the units of the
#'   projection of the UDs, where zero indicates identical UDs. `"earth_mover"`
#'   computes the exact distance with the suggested package `emdist`.
#'   `"earth_mover_sinkhorn"` uses the entropy-regularised Sinkhorn algorithm
#'   of [move2utils::emd()], which is much faster for large grids, with values
#'   typically within a few percent of the exact distance; it requires the
#'   suggested package `move2utils` (install it with
#'   `remotes::install_github("move2universe/move2utils")`). Default is
#'   `"ba"`.
#' @param cond_level Optional, the level for which the the conditional overlap
#'   is computed.
#' @param ... Additional arguments (not currently used)
#' @return A numeric value representing the overlap between the two UDs
#'   according to the specified method, or a matrix of such values if `x` is a
#'   tibble of multiple UDs.
#' @export
#' @examples
#' example_kde <- hr_tt_kde(example_tt)
#' hr_tt_ud_overlap(example_kde)
hr_tt_ud_overlap <- function(
  x,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover", "earth_mover_sinkhorn")
) {
  UseMethod("hr_tt_ud_overlap")
}

#' @export
#' @rdname hr_tt_ud_overlap
#' @param y A SpatRaster of the utilisation distribution, if `x` is a single UD.
#'   Else, if `x` is tibble of UDs, `y` is not used.
hr_tt_ud_overlap.SpatRaster <- function(
  x,
  y,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover", "earth_mover_sinkhorn"),
  cond_level = NULL
) {
  # as for a table of UDs: method and cond_level come after ..., so that
  # e.g. a method given by position would otherwise be silently ignored
  if (length(list(...)) > 0) {
    stop("additional arguments ... are not used")
  }
  method <- match.arg(method)
  check_earth_mover_available(method)
  check_ud_raster(x, "x")
  check_ud_raster(y, "y")
  # compare the two geometries
  if (!terra::compareGeom(x, y, stopOnError = FALSE)) {
    stop(
      "x and y must have the same geometry (i.e. same extent, ",
      "resolution, and CRS)"
    )
  }
  check_cond_level(cond_level)
  x_raw_values <- ud_values(x)
  y_raw_values <- ud_values(y)
  x_values <- condition_ud_values(x_raw_values, cond_level)
  y_values <- condition_ud_values(y_raw_values, cond_level)
  if (method == "earth_mover") {
    return(earth_mover_distance(x_values, y_values, x))
  } else if (method == "earth_mover_sinkhorn") {
    # the distance between the two UDs is the off-diagonal element
    return(earth_mover_sinkhorn(list(x_values, y_values), x)[1, 2])
  } else if (method == "udoi") {
    level <- udoi_level(cond_level)
    return(udoi_from_values(
      x_values,
      y_values,
      ud_level_mask(x_raw_values, level),
      ud_level_mask(y_raw_values, level),
      ud_cell_areas(x)
    ))
  } else {
    return(overlap_from_values(x_values, y_values, method))
  }
}

#' @export
#' @rdname hr_tt_ud_overlap
hr_tt_ud_overlap.hr_tt_ud_tbl <- function(
  x,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover", "earth_mover_sinkhorn"),
  cond_level = NULL
) {
  stopifnot_hr_tt_ud_table(x) # nolint: object_usage_linter.
  # Work with a plain list locally while preserving a loaded object's packing.
  x <- unwrap_ud_column(x) # nolint: object_usage_linter.

  # check that ... are empty
  if (length(list(...)) > 0) {
    stop("additional arguments ... are not used")
  }
  method <- match.arg(method)
  check_earth_mover_available(method)
  check_cond_level(cond_level)
  n <- nrow(x)
  # assume that the first column of x is an id column (check that it is
  # character and unique)
  if (is.character(x[[1]]) && length(unique(x[[1]])) == n) {
    ids <- x[[1]]
  } else {
    stop("the first column of x must be a character vector with unique values")
  }

  if (n == 0L) {
    return(matrix(numeric(), nrow = 0L, ncol = 0L, dimnames = list(ids, ids)))
  }

  reference <- x$ud[[1]]
  check_ud_raster(reference, "x$ud")
  ud_values_list <- vector("list", n)
  ud_mask_list <- vector("list", n)
  # Cache normalized cell values once per UD because every UD participates in
  # several pairwise comparisons.
  for (i in seq_len(n)) {
    ud <- x$ud[[i]]
    check_ud_raster(ud, "x$ud")
    if (!terra::compareGeom(reference, ud, stopOnError = FALSE)) {
      stop(
        "all UDs must have the same geometry (i.e. same extent, ",
        "resolution, and CRS)"
      )
    }
    raw_values <- ud_values(ud)
    ud_values_list[[i]] <- condition_ud_values(raw_values, cond_level)
    if (method == "udoi") {
      ud_mask_list[[i]] <- ud_level_mask(raw_values, udoi_level(cond_level))
    }
  }

  if (method == "ba") {
    # Each column contains one UD in matching cell order, allowing BA and UDOI
    # to calculate all pairwise products with one matrix cross-product.
    values_matrix <- do.call(cbind, ud_values_list)
    overlap_matrix <- crossprod(sqrt(values_matrix))
  } else if (method == "udoi") {
    values_matrix <- do.call(cbind, ud_values_list)
    mask_matrix <- do.call(cbind, ud_mask_list) * 1
    cell_areas <- ud_cell_areas(reference)
    # area of overlap of the home ranges times the integral of the product of
    # the UDs (densities are the cell probabilities divided by the cell areas)
    overlap_matrix <- crossprod(mask_matrix * cell_areas, mask_matrix) *
      crossprod(values_matrix / cell_areas, values_matrix)
  } else if (method == "earth_mover_sinkhorn") {
    # move2utils computes all pairwise distances at once (with zeros on the
    # diagonal), from the cached, conditioned cell values
    overlap_matrix <- earth_mover_sinkhorn(ud_values_list, reference)
  } else {
    diagonal <- if (method == "earth_mover") 0 else 1
    overlap_matrix <- diag(diagonal, n)
    if (n > 1L) {
      # VI and Earth Mover's Distance are calculated pairwise while reusing
      # the cached, conditioned cell values.
      for (i in seq_len(n - 1L)) {
        for (j in seq.int(i + 1L, n)) {
          value <- if (method == "earth_mover") {
            earth_mover_distance(
              ud_values_list[[i]],
              ud_values_list[[j]],
              reference
            )
          } else {
            sum(pmin(ud_values_list[[i]], ud_values_list[[j]]))
          }
          overlap_matrix[i, j] <- overlap_matrix[j, i] <- value
        }
      }
    }
  }

  # the overlap of a UD with itself is 1 for BA and VI (UDOI keeps the
  # computed value, see details)
  if (method %in% c("ba", "vi")) {
    diag(overlap_matrix) <- 1
  }
  rownames(overlap_matrix) <- colnames(overlap_matrix) <- ids
  overlap_matrix
}

#' Validate a utilisation-distribution raster
#'
#' Checks that a value is a `terra::SpatRaster` with a layer named `"ud"`,
#' which is the layer used by the overlap methods.
#'
#' @param x An object expected to be a `terra::SpatRaster`.
#' @param argument The argument name used in error messages.
#' @returns `NULL`, invisibly, when `x` is a valid UD raster.
#' @keywords internal
#' @noRd
check_ud_raster <- function(x, argument) {
  if (!inherits(x, "SpatRaster")) {
    stop(argument, " must be a SpatRaster")
  }
  if (!"ud" %in% names(x)) {
    stop(argument, " must have a layer named 'ud'")
  }
  invisible(NULL)
}

#' Validate a conditional overlap level
#'
#' @param cond_level `NULL` or one numeric value strictly between zero and one.
#' @returns `NULL`, invisibly, when `cond_level` is valid.
#' @keywords internal
#' @noRd
check_cond_level <- function(cond_level) {
  if (
    !is.null(cond_level) &&
      (length(cond_level) != 1 ||
         !is.numeric(cond_level) ||
         cond_level <= 0 ||
         cond_level >= 1)
  ) {
    stop("cond_level must be a single numeric value between 0 and 1")
  }
  invisible(NULL)
}

#' Extract values from a utilisation-distribution raster
#'
#' Reads only the layer named `"ud"` as a numeric vector. Single-layer rasters
#' use Terra's vector extraction path; multi-layer rasters are read as a matrix
#' so the requested layer can be selected by name.
#'
#' @param x A validated `terra::SpatRaster` with a layer named `"ud"`.
#' @returns A numeric vector of UD values in Terra cell order.
#' @keywords internal
#' @noRd
ud_values <- function(x) {
  if (terra::nlyr(x) == 1L) {
    return(terra::values(x, mat = FALSE))
  }
  values <- terra::values(x, mat = TRUE)
  values[, match("ud", names(x))]
}

#' Condition utilisation-distribution values
#'
#' Masks cells outside a cumulative utilisation-distribution level, rescales
#' retained values to sum to one, and replaces missing values with zero for
#' overlap calculations.
#'
#' @param values A numeric vector of UD values in cell order.
#' @param cond_level `NULL` or one numeric value strictly between zero and one.
#' @returns A numeric vector ready for overlap calculation.
#' @keywords internal
#' @noRd
condition_ud_values <- function(values, cond_level) {
  if (!is.null(cond_level)) {
    values[!ud_level_mask(values, cond_level)] <- NA_real_
    values <- values / sum(values, na.rm = TRUE)
  }
  values[is.na(values)] <- 0
  values
}

#' Find the cells within an isopleth of a utilisation distribution
#'
#' @param values A numeric vector of UD values in cell order.
#' @param level One numeric value strictly between zero and one.
#' @returns A logical vector, `TRUE` for the cells within the `level` isopleth
#'   (i.e. the cells with the highest values that, together, hold a proportion
#'   `level` of the UD). An error is given if no cell is within the isopleth.
#' @keywords internal
#' @noRd
ud_level_mask <- function(values, level) {
  # Restore cumulative values to their original cell positions after sorting
  # cells from highest to lowest UD value.
  order_index <- order(-values)
  cumulative_values <- cumsum(values[order_index])[order(order_index)]
  mask <- !is.na(cumulative_values) & cumulative_values <= level
  # on a grid that is coarse relative to the UD, the cell with the highest
  # value can hold more than `level` of the UD, leaving no cell within the
  # isopleth (which would silently give no overlap, even of a UD with itself)
  if (!any(mask)) {
    stop(
      "the ", level * 100, "% isopleth of a UD contains no cells, as a ",
      "single cell holds more than ", level * 100, "% of the UD; use UDs ",
      "estimated on a finer grid"
    )
  }
  mask
}

#' The isopleth level defining the home ranges for the UDOI
#'
#' @param cond_level `NULL` or one numeric value strictly between zero and one.
#' @returns `cond_level`, or 0.95 if `cond_level` is `NULL`.
#' @keywords internal
#' @noRd
udoi_level <- function(cond_level) {
  if (is.null(cond_level)) 0.95 else cond_level
}

#' Area of the cells of a utilisation-distribution raster
#'
#' @param raster A `terra::SpatRaster`.
#' @returns A numeric vector of cell areas in cell order (in m^2 for a
#'   longitude/latitude raster, otherwise in the squared units of the CRS).
#' @keywords internal
#' @noRd
ud_cell_areas <- function(raster) {
  if (nzchar(terra::crs(raster)) && terra::is.lonlat(raster)) {
    terra::values(terra::cellSize(raster[[1]], unit = "m"), mat = FALSE)
  } else {
    rep(prod(terra::res(raster)), terra::ncell(raster))
  }
}

#' Calculate the UDOI from conditioned UD values
#'
#' @param x,y Numeric vectors of conditioned UD values (cell probabilities).
#' @param x_mask,y_mask Logical vectors, `TRUE` for the cells within the home
#'   range of each UD.
#' @param cell_areas A numeric vector of cell areas.
#' @returns The UDOI.
#' @keywords internal
#' @noRd
udoi_from_values <- function(x, y, x_mask, y_mask, cell_areas) {
  # area of overlap of the home ranges times the integral of the product of
  # the UDs (densities are the cell probabilities divided by the cell areas)
  sum(cell_areas[x_mask & y_mask]) * sum(x * y / cell_areas)
}

#' Calculate overlap from conditioned UD values
#'
#' @param x A numeric vector of conditioned UD values.
#' @param y A numeric vector of conditioned UD values with matching cells.
#' @param method One of `"ba"` or `"vi"`.
#' @returns A numeric overlap value.
#' @keywords internal
#' @noRd
overlap_from_values <- function(x, y, method) {
  if (method == "ba") {
    sum(sqrt(x) * sqrt(y))
  } else {
    sum(pmin(x, y))
  }
}

#' Calculate Earth Mover's Distance between two UD value vectors
#'
#' @param x A numeric vector of conditioned UD values.
#' @param y A numeric vector of conditioned UD values.
#' @param raster A `SpatRaster` defining the grid of `x` and `y`.
#' @returns The Earth Mover's Distance between `x` and `y`.
#' @keywords internal
#' @noRd
earth_mover_distance <- function(x, y, raster) {
  check_earth_mover_available("earth_mover")
  n_rows <- terra::nrow(raster)
  n_cols <- terra::ncol(raster)
  resolution <- terra::res(raster)
  emdist::emd2d(
    matrix(x, nrow = n_rows, ncol = n_cols, byrow = TRUE),
    matrix(y, nrow = n_rows, ncol = n_cols, byrow = TRUE),
    xdist = resolution[1],
    ydist = resolution[2]
  )
}

#' Compute pairwise Earth Mover's Distances with the Sinkhorn algorithm
#'
#' @param values_list A list of numeric vectors of UD cell values (in the cell
#'   order of `raster`).
#' @param raster A `SpatRaster` giving the grid of the UDs.
#' @returns A symmetric matrix of the pairwise distances, with zeros on the
#'   diagonal.
#' @keywords internal
#' @noRd
earth_mover_sinkhorn <- function(values_list, raster) {
  n <- length(values_list)
  # move2utils::emd() gives an error with fewer than two UDs, whilst the
  # distance of a single UD to itself is simply zero
  if (n < 2L) {
    return(matrix(0, nrow = n, ncol = n))
  }
  # rebuild a multi-layer raster from the (possibly conditioned) cell values,
  # as move2utils::emd() takes rasters rather than values; the cell
  # coordinates, and hence the distances, are in the units of the crs
  uds <- terra::rast(raster[["ud"]], nlyrs = n)
  terra::values(uds) <- do.call(cbind, values_list)
  # unique layer names, as emd() uses them to name the rows and columns
  names(uds) <- paste0("ud", seq_len(n))
  # emd() also drops the outermost 0.1% of each UD before transporting it
  # (its default mask_quantile), which together with the entropic
  # regularisation explains the small differences from the exact distance;
  # it warns if the UDs are on a longitude/latitude grid
  distances <- as.matrix(move2utils::emd(uds, method = "sinkhorn"))
  # the callers set the ids as dimnames
  dimnames(distances) <- NULL
  distances
}

#' Check that the optional Earth Mover's Distance dependency is installed
#'
#' @param method The overlap method; only the Earth Mover's Distance methods
#'   need a suggested package.
#' @returns `NULL`, invisibly, when the package needed by `method` is installed.
#' @keywords internal
#' @noRd
check_earth_mover_available <- function(method) {
  # checked before any work is done, so that a missing package is reported
  # first; the other methods need no suggested package
  if (method == "earth_mover" && !requireNamespace("emdist", quietly = TRUE)) {
    stop(
      "method = 'earth_mover' requires the suggested package 'emdist'. ",
      "Install it with install.packages('emdist')."
    )
  }
  # the Sinkhorn approximation is a separate method, rather than a fallback
  # for a missing emdist, as its values differ slightly from the exact ones
  if (method == "earth_mover_sinkhorn") {
    check_move2utils("hr_tt_ud_overlap") # nolint: object_usage_linter.
  }
  invisible(NULL)
}


# deprecated function for backward compatibility
#' @rdname tidytracks-deprecated
#' @export
hr_ud_overlap <- function(...) {
  warning(
    "hr_ud_overlap is deprecated. Please use hr_tt_ud_overlap instead.",
    call. = FALSE
  )
  hr_tt_ud_overlap(...)
}
