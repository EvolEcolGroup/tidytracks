#' Compute overlap for utilisation distributions
#'
#' This function computes the overlap between pairs of utilisation distributions
#' (UDs) using various methods. If `x` is a `SpatRaster`, it computes the
#' overlap between `x` and `y`. If `x` is an `hr_ud_tbl`, it computes the
#' overlap for all unique pairs of UDs in the table. If `cond_level` is set, it
#' computes the conditional overlap for the specified level, which is the
#' overlap between the UDs estimated within a given isopleth level (e.g. 50%) of
#' the UD, rather than the full UD. This can be useful for comparing the core
#' areas of the UDs.
#' @param x A SpatRaster of the utilisation distribution (with a layer `ud`), or
#'   a tibble of UDs of class `hr_ud_tbl` (e.g. as created with [tt_hr_kde()]).
#' @param method A character string specifying the method to use for overlap
#'   calculation. Options are `"ba"` (Bhattacharyya's Affinity), `"vi"` (Volume
#'   of Intersection), and `"udoi"` (Utilisation Distribution Overlap Index).
#'   Default is `"ba"`.
#' @param cond_level Optional, the level for which the the conditional overlap
#'   is computed.
#' @param ... Additional arguments (not currently used)
#' @return A numeric value representing the overlap between the two UDs
#'   according to the specified method, or a matrix of such values if `x` is a
#'   tibble of multiple UDs.
#' @export

hr_ud_overlap <- function(x, ..., method = c("ba", "vi", "udoi")) {
  UseMethod("hr_ud_overlap")
}

#' @export
#' @rdname hr_ud_overlap
#' @param y A SpatRaster of the utilisation distribution, if `x` is a single UD. Else, if
#' `x` is tibble of UDs, `y` is not used.
hr_ud_overlap.SpatRaster <- function(x, y, ..., method = c("ba", "vi", "udoi"),
                                     cond_level = NULL) {
  method <- match.arg(method)
  # check that x has a layer named "ud"
  if (!"ud" %in% names(x)) {
    stop("x must have a layer named 'ud'")
  }
  # check that y is a SpatRaster and has a layer named "ud"
  if (!inherits(y, "SpatRaster") || !"ud" %in% names(y)) {
    stop("y must be a SpatRaster with a layer named 'ud'")
  }
  # compare the two geometries
  if (!terra::compareGeom(x, y, stopOnError = FALSE)) {
    stop("x and y must have the same geometry (i.e. same extent, ",
      "resolution, and CRS)")
  }
  # get x values as a matrix
  x_vals <- as.matrix(x$ud)
  # get y values as a matrix
  y_vals <- as.matrix(y$ud)
  
  if (!is.null(cond_level)) {
    # check that level is just one value between 0 and 1
    if (length(cond_level) != 1 || !is.numeric(cond_level) ||
        cond_level <= 0 || cond_level >= 1) {
      stop("cond_level must be a single numeric value between 0 and 1")
    }
    
    # compute the cumulative UD for x and y
    x_cud <- hr_cud(x)
    y_cud <- hr_cud(y)
    # get the values of the cumulative UD as a matrix
    x_cud_vals <- as.matrix(x_cud$cud)
    y_cud_vals <- as.matrix(y_cud$cud)
    # set values to NA where the cumulative UD is greater than the specified level
    x_vals[x_cud_vals > cond_level] <- NA
    y_vals[y_cud_vals > cond_level] <- NA
    # rescale the UD to 1
    x_vals <- x_vals / sum(x_vals, na.rm = TRUE)
    y_vals <- y_vals / sum(y_vals, na.rm = TRUE)
  }
  
  # missing values should be set to zero
  x_vals[is.na(x_vals)] <- 0
  y_vals[is.na(y_vals)] <- 0
  
  if (method == "ba") {
    return(sum(sqrt(x_vals)* sqrt(y_vals)))
  } else if (method == "vi") {
    return(sum(pmin(x_vals, y_vals)))
  } else if (method == "udoi") {
    return(sum(x_vals * y_vals))
  }
}

#' @export
#' @rdname hr_ud_overlap
hr_ud_overlap.hr_ud_tbl <- function(x, ..., method = c("ba", "vi", "udoi"),
                                    cond_level = NULL) {
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
                                           method = method,
                                           cond_level = cond_level)
        overlap_matrix[j, i] <- overlap_matrix[i, j]
      }
    }
    diag(overlap_matrix) <- 1
    return(overlap_matrix)
}