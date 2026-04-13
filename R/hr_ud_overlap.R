#' Compute overlap for utilisation distributions
#'
#' This function computes the overlap between pairs of utilisation distributions.
#' If x is a data.frame, it computes the overlap for all unique pairs of
#' UDs in the columns specified (kde by default).
#' (UDs) using various methods.
#' @param x A utilisation distribution object (a list of 3 elements, x, y and z),
#' or a data.frame containing multiple UDs in a specified column.
#' @param y A utilisation distribution object, if `x` is a single UD. Else, if
#' `x` is a data.frame, `y` should be NULL (the default).
#' @param ud_col A character string specifying the column name in `x` that
#'   contains the UDs. Default is "kde".
#' @param method A character string specifying the method to use for overlap
#'   calculation. Options will include "BA" (Bhattacharyya's Affinity), "VI" (Volume
#'   of Intersection), and "UDOI" (Utilisation Distribution Overlap Index).
#'   Currently only "BA" is implemented. Default is "BA".
#' @return A numeric value representing the overlap between the two UDs
#'   according to the specified method, or a matrix of such values if `x` is
#'   a data.frame with multiple UDs.
#' @export

hr_ud_overlap <- function(x, y = NULL, ud_col = "kde", method = "BA") {
  warning("this function has not been fully tested yet")
  if (is.data.frame(x)) {
    if (!is.null(y)) {
      stop("If 'x' is a data.frame, 'y' must be NULL.")
    }
    ud_list <- x[[ud_col]]
    n <- length(ud_list)
    overlap_matrix <- matrix(NA, nrow = n, ncol = n)
    colnames(overlap_matrix) <- rownames(overlap_matrix) <- rownames(x)
    for (i in 1:(n - 1)) {
      for (j in (i + 1):n) {
        overlap_matrix[i, j] <- ud_overlap(ud_list[[i]], ud_list[[j]], method = method)
        overlap_matrix[j, i] <- overlap_matrix[i, j]
      }
    }
    diag(overlap_matrix) <- 1
    return(overlap_matrix)
  } else {
    if (is.null(y)) {
      stop("If 'x' is a single UD, 'y' must be provided.")
    }
    if (method == "BA") {
      # Bhattacharyya's Affinity
      z1 <- x$z / sum(x$z)
      z2 <- y$z / sum(y$z)
      ba <- sum(sqrt(z1 * z2))
      return(ba)
    } else {
      stop(paste("Method", method, "not implemented."))
    }
  }
}