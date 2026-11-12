#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description This function computes the cumulative utilisation distribution
#' (CUD). `x` can be either a `SpatRaster` with a layer named `"ud"` or a
#' numeric matrix of UD values. `return_matrix` controls the return type: when
#' `TRUE` a numeric matrix is returned; when `FALSE` a `SpatRaster` is
#' returned. By default the return type matches the input type. A `SpatRaster`
#' is only created when required for the return value. Cells with the same UD
#' value share the same cumulative UD (see `cumulative_ud()`).
#'
#' @param x A `SpatRaster` with a layer named `"ud"`, or a numeric matrix of
#'   UD values.
#' @param return_matrix Logical. If `TRUE`, a numeric matrix of cumulative UD
#'   values is returned. If `FALSE`, a `terra::SpatRaster` is returned. When
#'   `x` is a matrix and `return_matrix = FALSE`, a SpatRaster cannot be
#'   constructed and an error is raised. Defaults to `TRUE` when `x` is a
#'   matrix and `FALSE` when `x` is a `SpatRaster` (i.e. returns the same type
#'   as the input by default).
#' @return A `terra::SpatRaster` representing the cumulative utilisation
#'   distribution (UD) when `return_matrix = FALSE`, or a numeric matrix when
#'   `return_matrix = TRUE`. Matrices returned from a `SpatRaster` have the
#'   same number of rows and columns as the raster.
#' @keywords internal
#' @noRd

hr_tt_cud <- function(x, return_matrix = !inherits(x, "SpatRaster")) {
  if (!inherits(x, "SpatRaster") && !return_matrix) {
    stop(
      "cannot return a SpatRaster when x is a matrix; use return_matrix = TRUE"
    )
  }
  if (inherits(x, "SpatRaster")) {
    if (!"ud" %in% names(x)) {
      stop("x must have a layer named 'ud'")
    }
    ud <- x[["ud"]]
    # the UD values in the order of the cells (row by row, from the north):
    # the cumulative UD does not depend on how they are laid out
    vals <- terra::values(ud, mat = FALSE)
  } else {
    # x is already a numeric matrix or vector
    ud <- NULL
    vals <- x
  }

  cud_flat <- cumulative_ud(vals)

  if (is.null(ud)) {
    return(matrix(cud_flat, nrow = nrow(vals), ncol = ncol(vals)))
  }
  if (return_matrix) {
    # laid out as the raster
    return(matrix(cud_flat, nrow = terra::nrow(ud), byrow = TRUE))
  }
  # store the cumulative UD values back into a SpatRaster
  cud <- terra::setValues(ud, cud_flat)
  names(cud) <- "cud"
  return(cud)
}

#' Cumulative UD of each cell
#'
#' Internal function used by `hr_tt_cud()` and `ud_level_mask()`: the
#' cumulative UD of a cell is the sum of its UD and of the UD of all the cells
#' with a higher UD, i.e. the proportion of the UD within the smallest
#' isopleth that contains the cell.
#'
#' Cells with the same UD (as in a symmetric UD) would get different
#' cumulative UDs depending on the order in which they are summed (e.g. the
#' order of the cells in the raster), which would split them arbitrarily
#' between the inside and the outside of an isopleth (and make the isopleths
#' of a symmetric UD asymmetric). Instead, they share the mean of the
#' cumulative UDs that they would have in any order (as average ranks do for
#' ties), so that they are either all within an isopleth or all outside it,
#' and an isopleth keeps, on average, the area it has when they are split.
#'
#' @param values a numeric vector (or matrix) of UD values, with `NA` for the
#'   cells without a value.
#' @returns A numeric vector with the cumulative UD of each cell, in the
#'   order of `values` (`NA` for the cells without a value).
#' @keywords internal
#' @noRd
cumulative_ud <- function(values) {
  values <- as.numeric(values)
  # the cells from the highest UD to the lowest, with the cells without a
  # value last (whose cumulative UD is NA)
  ord <- order(values, decreasing = TRUE, na.last = TRUE)
  sorted <- values[ord]
  cumulative <- cumsum(sorted)
  # Each run of cells with the same UD gets the mean of their cumulative UDs.
  # Within a run, the cumulative UD increases by the same UD from one cell
  # to the next, so their mean is that of the first and last cells of the run.
  n <- sum(!is.na(sorted))
  if (n > 1) {
    known <- seq_len(n)
    run_end <- c(sorted[known[-1]] != sorted[known[-n]], TRUE)
    run_start <- c(TRUE, run_end[-n])
    run <- cumsum(run_start)
    run_mean <- (cumulative[which(run_start)] + cumulative[which(run_end)]) / 2
    cumulative[known] <- run_mean[run]
  }
  # back to the order of the cells
  out <- numeric(length(values))
  out[ord] <- cumulative
  out
}
