#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description
#' This function takes a matrix representing the UD and returns
#' the cumulative utilisation distribution (UD).
#'
#' @param x A SpatRaster of the UD.
#' @return A matrix representing the cumulative utilisation distribution (UD).
#' @keywords internal

hr_cud <- function(x) {
  # create a copy of the input SpatRaster to store the cumulative UD values
  cud <- x
  names(cud) <- "cud"
  # compute the cumulative sum of the UD values, ordered from highest to lowest
  cud_vals <- terra::values(x)
  cud_vals <- cumsum(cud_vals[order(-cud_vals)])[order(order(-cud_vals))]
  terra::values(cud) <- cud_vals
  return(cud)
}
