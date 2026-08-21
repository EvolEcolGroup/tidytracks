#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description This function computes the cumulative utilisation distribution
#' (CUD). `x` can be either a `SpatRaster` with a layer named `"ud"` or a
#' numeric matrix of UD values. `return_matrix` controls the return type: when
#' `TRUE` a numeric matrix is returned; when `FALSE` a `SpatRaster` is
#' returned. By default the return type matches the input type. A `SpatRaster`
#' is only created when required for the return value.
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
#'   distribution (UD) when `return_matrix = FALSE`, or a numeric matrix of
#'   the same dimensions when `return_matrix = TRUE`.
#' @keywords internal
#' @noRd

hr_cud <- function(x, return_matrix = !inherits(x, "SpatRaster")) {
  if (!inherits(x, "SpatRaster") && !return_matrix) {
    stop("cannot return a SpatRaster when x is a matrix; use return_matrix = TRUE")
  }
  if (inherits(x, "SpatRaster")) {
    # extract the UD values as a matrix from the raster
    if (!"ud" %in% names(x)) {
      stop("x must have a layer named 'ud'")
    }
    ud <- x[["ud"]]
    vals <- as.matrix(ud)
  } else {
    # x is already a numeric matrix or vector
    ud <- NULL
    vals <- x
  }

  # compute the cumulative sum of the UD values, ordered from highest to lowest
  flat <- as.numeric(vals)
  ord <- order(-flat)
  cud_flat <- cumsum(flat[ord])[order(ord)]
  cud_mat <- matrix(cud_flat, nrow = nrow(vals), ncol = ncol(vals))

  if (return_matrix) {
    return(cud_mat)
  }

  # store the cumulative UD values back into a SpatRaster
  cud <- ud
  names(cud) <- "cud"
  terra::values(cud) <- cud_flat
  return(cud)
}
