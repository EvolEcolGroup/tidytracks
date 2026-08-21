#' Wrap utilisation distributions for storage
#'
#' Converts the `ud` column of an `hr_ud_tbl` from a plain list of
#' `terra::SpatRaster` objects to a compact wrapped `PackedSpatRaster_list`. Use
#' [hr_ud_unwrap()] to restore the standard in-memory representation.
#'
#' @param x An `hr_ud_tbl` with a `ud` list-column.
#' @returns A copy of `x` with a wrapped `ud` column.
#' @export
#' @examples
#' example_kde <- hr_kde(example_tt)
#' wrapped_kde <- hr_ud_wrap(example_kde)
hr_ud_wrap <- function(x) {
  stopifnot_hr_ud_tbl(x)

  if (inherits(x$ud, "PackedSpatRaster_list")) {
    return(x)
  }

  if (!is.list(x$ud) ||
        !all(vapply(x$ud, inherits, logical(1), "SpatRaster"))) {
    stop("x$ud must be a list of SpatRaster objects")
  }

  x$ud <- PackedSpatRaster_list(x$ud)
  x
}

#' Unwrap utilisation distributions after loading
#'
#' Converts the `ud` column of an `hr_ud_tbl` from a
#' wrapped `PackedSpatRaster_list` to the standard plain list of
#' `terra::SpatRaster` objects. This is needed after loading a file created
#' with [hr_ud_saveRDS()].
#' Functions that operate on `hr_ud_tbl` objects unwrap their input
#' automatically, but explicitly unwrapping avoids repeating that work across
#' multiple operations.
#'
#' @param x An `hr_ud_tbl` with a `ud` list-column.
#' @returns A copy of `x` with an unwrapped `ud` column.
#' @export
#' @examples
#' example_kde <- hr_kde(example_tt)
#' unwrapped_kde <- hr_ud_unwrap(hr_ud_wrap(example_kde))
hr_ud_unwrap <- function(x) {
  stopifnot_hr_ud_tbl(x)

  if (!inherits(x$ud, "PackedSpatRaster_list")) {
    if (!is.list(x$ud) ||
          !all(vapply(x$ud, inherits, logical(1), "SpatRaster"))) {
      stop(
        paste(
          "x$ud must be a wrapped PackedSpatRaster_list",
          "or a list of SpatRaster objects"
        )
      )
    }
    return(x)
  }

  unwrap_ud_column(x)
}

#' Unwrap a UD column without class validation
#'
#' Converts a wrapped `ud` list-column to a plain list of
#' `terra::SpatRaster` objects. This internal helper supports tibble methods
#' whose `hr_ud_tbl` class was removed by dplyr grouping operations.
#'
#' @param x A tibble with a `ud` column.
#' @returns A copy of `x` with an unwrapped `ud` column when necessary.
#' @keywords internal
#' @noRd
unwrap_ud_column <- function(x) {
  if (inherits(x$ud, "PackedSpatRaster_list")) {
    x$ud <- as.list(x$ud)
  }
  x
}

#' Save utilisation distributions as an RDS file
#'
#' Wraps an `hr_ud_tbl` before saving it with [base::saveRDS()]. This avoids
#' writing live `terra::SpatRaster` objects to disk. The object returned by
#' [base::readRDS()] has a wrapped `ud` column. Functions that operate on an
#' `hr_ud_tbl` unwrap this column automatically; use [hr_ud_unwrap()] to
#' restore it explicitly for repeated analyses.
#'
#' @param x An `hr_ud_tbl` with a `ud` list-column.
#' @param file A connection or character string naming the RDS file.
#' @param compress A logical or character value passed to [base::saveRDS()].
#' @param version The RDS serialization format version passed to
#'   [base::saveRDS()].
#' @param ... Additional arguments passed to [base::saveRDS()].
#' @returns `NULL`, invisibly.
#' @export
#' @examples
#' \dontrun{
#' example_kde <- hr_kde(example_tt)
#' hr_ud_saveRDS(example_kde, "example-kde.rds")
#' loaded_kde <- readRDS("example-kde.rds")
#' }
hr_ud_saveRDS <- function(x, file, compress = TRUE, version = NULL, ...) { # nolint
  base::saveRDS(
    hr_ud_wrap(x),
    file = file,
    compress = compress,
    version = version,
    ...
  )
}

stopifnot_hr_ud_tbl <- function(x) {
  if (!inherits(x, "hr_ud_tbl") && !inherits(x, "grouped_df")) {
    stop("x must be an hr_ud_tbl or a grouped tibble")
  }
  if (!"ud" %in% names(x)) {
    stop("x must have a column named 'ud'")
  }
}
