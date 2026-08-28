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
#'
#' @details When `x` is an `hr_ud_tbl`, each UD is validated, converted to cell
#' values, and conditionally masked once before all pairwise comparisons are
#' calculated. This avoids repeated raster reads and cumulative-distribution
#' calculations for UDs that occur in multiple pairs.
#' @param x A SpatRaster of the utilisation distribution (with a layer `ud`), or
#'   a tibble of UDs of class `hr_ud_tbl` (e.g. as created with [hr_kde()]).
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
#' @examples
#' example_kde <- hr_kde(example_tt)
#' hr_ud_overlap(example_kde)
hr_ud_overlap <- function(x, ..., method = c("ba", "vi", "udoi")) {
  UseMethod("hr_ud_overlap")
}

#' @export
#' @rdname hr_ud_overlap
#' @param y A SpatRaster of the utilisation distribution, if `x` is a single UD.
#'   Else, if `x` is tibble of UDs, `y` is not used.
hr_ud_overlap.SpatRaster <- function(
  x,
  y,
  ...,
  method = c("ba", "vi", "udoi"),
  cond_level = NULL
) {
  method <- match.arg(method)
  check_ud_raster(x, "x")
  check_ud_raster(y, "y")
  # compare the two geometries
  if (!terra::compareGeom(x, y, stopOnError = FALSE)) {
    stop(
      "x and y must have the same geometry (i.e. same extent, ",
      "resolution, and CRS)"
    )
  }
  check_cond_level(cond_level)
  # Convert only the requested UD layer to vectors before applying overlap math.
  overlap_from_values(
    condition_ud_values(ud_values(x), cond_level),
    condition_ud_values(ud_values(y), cond_level),
    method
  )
}

#' @export
#' @rdname hr_ud_overlap
# Note that we have a generic method for a tibble as the hr_ud_tbl class is lost
# on group_map operations

hr_ud_overlap.hr_ud_tbl <- function(
  x,
  ...,
  method = c("ba", "vi", "udoi"),
  cond_level = NULL
) {
  stopifnot_hr_ud_table(x) # nolint: object_usage_linter.
  # Work with a plain list locally while preserving a loaded object's packing.
  x <- unwrap_ud_column(x) # nolint: object_usage_linter.

  # check that ... are empty
  if (length(list(...)) > 0) {
    stop("additional arguments ... are not used")
  }
  method <- match.arg(method)
  check_cond_level(cond_level)
  n <- nrow(x)
  # assume that the first column of x is an id column (check that it is
  # character and unique)
  if (is.character(x[[1]]) && length(unique(x[[1]])) == n) {
    ids <- x[[1]]
  } else {
    stop("the first column of x must be a character vector with unique values")
  }

  if (n == 0L) {
    return(matrix(numeric(), nrow = 0L, ncol = 0L, dimnames = list(ids, ids)))
  }

  reference <- x$ud[[1]]
  check_ud_raster(reference, "x$ud")
  ud_values_list <- vector("list", n)
  # Cache normalized cell values once per UD because every UD participates in
  # several pairwise comparisons.
  for (i in seq_len(n)) {
    ud <- x$ud[[i]]
    check_ud_raster(ud, "x$ud")
    if (!terra::compareGeom(reference, ud, stopOnError = FALSE)) {
      stop(
        "all UDs must have the same geometry (i.e. same extent, ",
        "resolution, and CRS)"
      )
    }
    ud_values_list[[i]] <- condition_ud_values(ud_values(ud), cond_level)
  }

  # Each column contains one UD in matching cell order, allowing BA and UDOI to
  # calculate all pairwise products with one matrix cross-product.
  values_matrix <- do.call(cbind, ud_values_list)
  if (method == "ba") {
    overlap_matrix <- crossprod(sqrt(values_matrix))
  } else if (method == "udoi") {
    overlap_matrix <- crossprod(values_matrix)
  } else {
    overlap_matrix <- diag(1, n)
    if (n > 1L) {
      # VI requires the cell-wise minimum, so it cannot be expressed as a
      # cross-product. It still reuses the cached vectors.
      for (i in seq_len(n - 1L)) {
        for (j in seq.int(i + 1L, n)) {
          overlap_matrix[i, j] <- overlap_matrix[j, i] <-
            sum(pmin(ud_values_list[[i]], ud_values_list[[j]]))
        }
      }
    }
  }

  diag(overlap_matrix) <- 1
  rownames(overlap_matrix) <- colnames(overlap_matrix) <- ids
  overlap_matrix
}

#' Validate a utilisation-distribution raster
#'
#' Checks that a value is a `terra::SpatRaster` with a layer named `"ud"`,
#' which is the layer used by the overlap methods.
#'
#' @param x An object expected to be a `terra::SpatRaster`.
#' @param argument The argument name used in error messages.
#' @returns `NULL`, invisibly, when `x` is a valid UD raster.
#' @keywords internal
#' @noRd
check_ud_raster <- function(x, argument) {
  if (!inherits(x, "SpatRaster")) {
    stop(argument, " must be a SpatRaster")
  }
  if (!"ud" %in% names(x)) {
    stop(argument, " must have a layer named 'ud'")
  }
  invisible(NULL)
}

#' Validate a conditional overlap level
#'
#' @param cond_level `NULL` or one numeric value strictly between zero and one.
#' @returns `NULL`, invisibly, when `cond_level` is valid.
#' @keywords internal
#' @noRd
check_cond_level <- function(cond_level) {
  if (
    !is.null(cond_level) &&
      (length(cond_level) != 1 ||
         !is.numeric(cond_level) ||
         cond_level <= 0 ||
         cond_level >= 1)
  ) {
    stop("cond_level must be a single numeric value between 0 and 1")
  }
  invisible(NULL)
}

#' Extract values from a utilisation-distribution raster
#'
#' Reads only the layer named `"ud"` as a numeric vector. Single-layer rasters
#' use Terra's vector extraction path; multi-layer rasters are read as a matrix
#' so the requested layer can be selected by name.
#'
#' @param x A validated `terra::SpatRaster` with a layer named `"ud"`.
#' @returns A numeric vector of UD values in Terra cell order.
#' @keywords internal
#' @noRd
ud_values <- function(x) {
  if (terra::nlyr(x) == 1L) {
    return(terra::values(x, mat = FALSE))
  }
  values <- terra::values(x, mat = TRUE)
  values[, match("ud", names(x))]
}

#' Condition utilisation-distribution values
#'
#' Masks cells outside a cumulative utilisation-distribution level, rescales
#' retained values to sum to one, and replaces missing values with zero for
#' overlap calculations.
#'
#' @param values A numeric vector of UD values in cell order.
#' @param cond_level `NULL` or one numeric value strictly between zero and one.
#' @returns A numeric vector ready for overlap calculation.
#' @keywords internal
#' @noRd
condition_ud_values <- function(values, cond_level) {
  if (!is.null(cond_level)) {
    # Restore cumulative values to their original cell positions after sorting
    # cells from highest to lowest UD value.
    order_index <- order(-values)
    cumulative_values <- cumsum(values[order_index])[order(order_index)]
    values[cumulative_values > cond_level] <- NA_real_
    values <- values / sum(values, na.rm = TRUE)
  }
  values[is.na(values)] <- 0
  values
}

#' Calculate overlap from conditioned UD values
#'
#' @param x A numeric vector of conditioned UD values.
#' @param y A numeric vector of conditioned UD values with matching cells.
#' @param method One of `"ba"`, `"vi"`, or `"udoi"`.
#' @returns A numeric overlap value.
#' @keywords internal
#' @noRd
overlap_from_values <- function(x, y, method) {
  if (method == "ba") {
    sum(sqrt(x) * sqrt(y))
  } else if (method == "vi") {
    sum(pmin(x, y))
  } else {
    sum(x * y)
  }
}
