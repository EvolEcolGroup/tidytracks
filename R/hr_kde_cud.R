#' Compute the cumulative Utilisation Distribution (UD)
#'
#' @description
#' This function takes a matrix representing the estimated density and returns
#' the cumulative utilisation distribution (UD).
#'
#' @param x A matrix representing the estimated density.
#' @return A matrix representing the cumulative utilisation distribution (UD).
#' @keywords internal

hr_kde_cud <- function(x) {
  cud <- as.vector(x)
  cud <- cud / sum(cud, na.rm = TRUE)  # standarize
  cud <- cumsum(cud[order(-cud)])[order(order(-cud))]
  cud <- matrix(cud, nrow = nrow(x), ncol = ncol(x))
  return(cud)
}
