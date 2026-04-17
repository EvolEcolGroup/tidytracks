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
  # NOTE in adehabitatHR this is first multiplied by res^2 to get the volume
  ud_matrix <- terra::as.array(x$ud)[,,1]
  # in terra, the y axis is reversed compared to the cartesian plane, so we need to flip it back
   ud_matrix <- ud_matrix[nrow(ud_matrix):1,]  
  cud <- list(x = terra::xFromCol(x),
              y = terra::yFromRow(x)[nrow(ud_matrix):1])
  cud$z <- as.vector(terra::as.array(x))
  # in terra, the y axis is reversed compared to the cartesian plane, so we need to flip it back
  
##  cud <- cud / sum(cud, na.rm = TRUE) # standarize
  cud$z <- cumsum(cud$z[order(-cud$z)])[order(order(-cud$z))]
  cud$z <- matrix(cud$z, nrow = nrow(x), ncol = ncol(x))
  return(cud)
}
