#' Compute h_ref for KDE, one value per group
#'
#' @description This computes the reference bandwidth for the a bivariate normal
#' kernel.
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A vector of bandwidths, one for each group
#' @keywords internal
#' @noRd

h_ref_indiv <- function(xy, group_index) {
  # compute the bandwidth for each group (i.e. subset xy by group_index)
  h_ref <- lapply(unique(group_index), function(i) {
    # get the coordinates for this group
    xy_sub <- xy[group_index == i, ]
    # compute the bandwidth for this group
    (sqrt(
      0.5 *
        (stats::var(xy_sub[, 1]) +
           stats::var(xy_sub[, 2]))
    )) *
      (nrow(xy_sub)^-(1 / 6))
  })
  return(unlist(h_ref))
}

#' Compute h_ref for KDE, returning the mean value
#'
#' @description This computes the reference bandwidth for the a bivariate normal
#' kernel.
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A single value, the mean of the bandwidths for each group
#' @keywords internal
#' @noRd

h_ref_mean <- function(xy, group_index) {
  h_ref <- h_ref_indiv(xy, group_index)
  return(mean(h_ref))
}
