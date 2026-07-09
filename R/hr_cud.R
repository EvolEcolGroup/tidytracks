#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description This function takes a SpatRaster representing the UD and returns
#' a SpatRaster containing the cumulative utilisation distribution (UD).
#'
#' @param x A SpatRaster of the UD.
#' @return A `terra::SpatRaster` representing the cumulative utilisation
#'   distribution (UD).
#' @keywords internal

hr_cud <- function(x) {
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
