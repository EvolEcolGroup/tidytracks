#' Compute overlap for utilisation distributions
#'
#' This function computes the overlap between pairs of utilisation distributions.
#' If x is a data.frame, it computes the overlap for all unique pairs of
#' UDs in the columns specified (kde by default).
#' (UDs) using various methods.
#' @param x A SpatRaster of the utilisation distribution (with a layer `ud`),
#' or a tibble of UDs of class `hr_ud_tbl` (e.g. as created with [tt_hr_kde()].
#' @param method A character string specifying the method to use for overlap
#'   calculation. Options will include "ba" (Bhattacharyya's Affinity), "vi" (Volume
#'   of Intersection), and "udoi" (Utilisation Distribution Overlap Index).
#'   Currently only "ba" is implemented. Default is "ba".
#' @param ... Additional arguments (not currently used)
#' @return A numeric value representing the overlap between the two UDs
#'   according to the specified method, or a matrix of such values if `x` is
#'   a tibble of multiple UDs.
#' @export

hr_ud_overlap <- function(x, ..., method = c("ba", "vi", "udoi")) {
  UseMethod("hr_ud_overlap")
}

#' @export
#' @rdname hr_ud_overlap
#' @param y A SpatRaster of the utilisation distribution, if `x` is a single UD. Else, if
#' `x` is tibble of UDs, `y` is not used.
hr_ud_overlap.SpatRaster <- function(x, y, ..., method = c("ba", "vi", "udoi")) {
  method <- match.arg(method)
  if (method == "ba") {
    return(sum(sqrt(x[])* sqrt(y[])))
  } else if (method == "vi") {
    return(sum(pmin(x[], y[])))
  } else if (method == "udoi") {
    return(sum(x[] * y[]))
  }
}

#' @export
#' @rdname hr_ud_overlap
hr_ud_overlap.hr_ud_tbl <- function(x, ..., method = c("ba", "vi", "udoi")) {
  # check that ... are empty
  if (length(list(...)) > 0) {
    stop("additional arguments ... are not used")
  }
  n <- nrow(x)
  overlap_matrix <- matrix(NA, nrow = n, ncol = n)
  # assume that the first column of x is an id column (check that it is
  # character and unique)
   if (is.character(x[[1]]) && length(unique(x[[1]])) == n) {
     rownames(overlap_matrix) <- colnames(overlap_matrix) <- x[[1]]
   } else {
     stop("the first column of x must be a character vector with unique values")
   }
    for (i in 1:(n - 1)) {
      for (j in (i + 1):n) {
        overlap_matrix[i, j] <- hr_ud_overlap(x$ud[[i]], x$ud[[j]],
                                           method = method)
        overlap_matrix[j, i] <- overlap_matrix[i, j]
      }
    }
    diag(overlap_matrix) <- 1
    return(overlap_matrix)
}