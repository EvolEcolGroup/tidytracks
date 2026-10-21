#' Compute h_ref for KDE, one value per group
#'
#' @description This computes the reference bandwidth for the a bivariate normal
#' kernel.
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A vector of bandwidths, one for each group, ordered by group index
#'   (so that the bandwidth for group `i` is element `i`). The bandwidth is
#'   `NA` for groups with fewer than two distinct locations, for which it is
#'   undefined.
#' @keywords internal
#' @noRd

h_ref_indiv <- function(xy, group_index) {
  # compute the bandwidth for each group (i.e. subset xy by group_index); the
  # groups are processed in index order, not in order of first appearance, as
  # callers look up the bandwidth of group `i` as element `i`
  h_ref <- lapply(sort(unique(group_index)), function(i) {
    # get the coordinates for this group
    xy_sub <- xy[group_index == i, , drop = FALSE]
    # compute the bandwidth for this group
    h_ref <- (sqrt(
      0.5 *
        (stats::var(xy_sub[, 1]) + stats::var(xy_sub[, 2]))
    )) *
      (nrow(xy_sub)^-(1 / 6))
    # a single location, or identical locations, give no information on the
    # spread of the locations (NA or 0)
    if (is.na(h_ref) || h_ref <= 0) NA_real_ else h_ref
  })
  return(unlist(h_ref))
}

#' Compute h_ref for KDE, returning the mean value
#'
#' @description This computes the reference bandwidth for the a bivariate normal
#' kernel.
#' @param xy A matrix of coordinates
#' @param group_index A vector of group indices
#' @returns A single value, the mean of the bandwidths for each group (for
#'   which a bandwidth can be computed, see `h_ref_indiv()`)
#' @keywords internal
#' @noRd

h_ref_mean <- function(xy, group_index) {
  h_ref <- h_ref_indiv(xy, group_index)
  return(mean(h_ref, na.rm = TRUE))
}
