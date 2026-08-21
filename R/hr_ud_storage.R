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
#' with [hr_ud_save()].
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

  x$ud <- as.list(x$ud)
  x
}

#' Save utilisation distributions as an RDS file
#'
#' Wraps an `hr_ud_tbl` before saving it with [base::saveRDS()]. This avoids
#' writing live `terra::SpatRaster` objects to disk. The object returned by
#' [base::readRDS()] has a wrapped `ud` column; use [hr_ud_unwrap()] before
#' further analysis.
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
#' hr_ud_save(example_kde, "example-kde.rds")
#' loaded_kde <- hr_ud_unwrap(readRDS("example-kde.rds"))
#' }
hr_ud_save <- function(x, file, compress = TRUE, version = NULL, ...) {
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
