#' Compute h_ref for KDE, one value per group
#'
#' @description This uses the standard formula for the reference bandwidth
#' for KDE
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A vector of bandwidths, one for each group
#' @keywords internal

h_ref_indiv <- function(xy, group_index) {
  # compute the bandwidth for each group (i.e. subset xy by group_index)
  h_ref <- lapply(unique(group_index), function(i) {
    # get the coordinates for this group
    xy_sub <- xy[group_index == i, ]
    # compute the bandwidth for this group
    (sqrt(0.5 * (stats::var(xy_sub[, 1]) +
      stats::var(xy_sub[, 2])))) * (nrow(xy_sub)^-(1 / 6))
  })
  return(unlist(h_ref))
}

#' Compute h_ref for KDE, returning the mean value
#'
#' @description This uses the standard formula for the reference bandwidth
#' for KDE
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A single value, the mean of the bandwidths for each group
#' @keywords internal

h_ref_mean <- function(xy, group_index) {
  h_ref <- h_ref_indiv(xy, group_index)
  return(mean(h_ref))
}

#' Compute h_ref for KDE using the adehabitatHR method, one value per group
#'
#' @description This uses the adehabitatHR method for computing the reference
#' bandwidth, which multiplies the standard formula by 4
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A vector of bandwidths, one for each group
#' @keywords internal

h_ref_ade_indiv <- function(xy, group_index) {
  h_ref <- h_ref_indiv(xy, group_index)
  return(h_ref * 4)
}

#' Compute h_ref for KDE using the adehabitatHR method, returning the mean value
#'
#' @description This uses the adehabitatHR method for computing the reference
#' bandwidth, which multiplies the standard formula by 4
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A single value, the mean of the bandwidths for each group
#' @keywords internal

h_ref_ade_mean <- function(xy, group_index) {
  h_ref <- h_ref_ade_indiv(xy, group_index)
  return(mean(h_ref))
}

h_ref_one_group <- function(xy) {
  h_ref <- (sqrt(0.5 * (stats::var(xy[, 1]) + stats::var(xy[, 2])))) *
    (nrow(xy)^-(1 / 6))
  return(h_ref)
}
