#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description This function takes a SpatRaster representing the UD and returns
#' a SpatRaster containing the cumulative utilisation distribution (UD).
#' When `return_matrix = TRUE`, `x` should be a numeric matrix (or vector) of
#' UD values and a matrix of the same dimensions is returned directly, with no
#' SpatRaster creation or operations.
#'
#' @param x A SpatRaster of the UD, or (when `return_matrix = TRUE`) a numeric
#'   matrix or vector of UD values.
#' @param return_matrix Logical. If `TRUE`, `x` is treated as a numeric matrix
#'   (or vector) and a matrix of cumulative UD values is returned without any
#'   SpatRaster operations. Default is `FALSE`.
#' @return A `terra::SpatRaster` representing the cumulative utilisation
#'   distribution (UD), or (when `return_matrix = TRUE`) a numeric matrix of
#'   the same dimensions as `x`.
#' @keywords internal
#' @noRd

hr_cud <- function(x, return_matrix = FALSE) {
  if (return_matrix) {
    # x is already a numeric matrix or vector; compute CUD directly
    vals <- as.numeric(x)
    ord <- order(-vals)
    cud_vals <- cumsum(vals[ord])[order(ord)]
    return(matrix(cud_vals, nrow = nrow(x), ncol = ncol(x)))
  }
  # check that x has a layer named "ud"
  if (!"ud" %in% names(x)) {
    stop("x must have a layer named 'ud'")
  }
  # create a single-layer copy of the UD raster to store the cumulative UD
  # values
  ud <- x[["ud"]]
  cud <- ud
  names(cud) <- "cud"
  # compute the cumulative sum of the UD values, ordered from highest to lowest
  cud_vals <- terra::values(ud)
  cud_vals <- cumsum(cud_vals[order(-cud_vals)])[order(order(-cud_vals))]
  terra::values(cud) <- cud_vals
  return(cud)
}
