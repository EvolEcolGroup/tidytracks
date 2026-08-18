#' Compute the normalised sum of multiple UDs
#'
#' This functions takes a tibble of UDs and computes the normalised sum of the
#' UDs. The normalised sum is computed by summing the UDs and then dividing by
#' the number of UDs so that the resulting UD has a maximum value of 1 (this is
#' the same as dividing by the sum of values in the combined UDs).
#'
#' @param x A tibble of UDs (potentially grouped), where each row is a UD in the
#'   column named "ud", or a list of SpatRaster objects representing UDs.
#' @returns either a tibble of UDs with the number of rows equal to the number
#'   of groups in `x` (or just one row for an ungrouped tibble), or a single
#'   SpatRaster if `x` is a list of SpatRaster objects.
#' @export
#' @examples
#' example_kde <- hr_kde(example_tt)
#' # sum the UDs for all tracks in the tibble
#' hr_ud_sum(example_kde)
#' # add sex info from metadata and use it to group the UDs
#' example_kde_grouped <- example_kde %>%
#'  left_join(show_meta(example_tt)) %>%
#'  group_by(sex)
#' hr_ud_sum(example_kde_grouped)
#' @family home_range

hr_ud_sum <- function(x) {
  UseMethod("hr_ud_sum")
}

#' @export
#' @rdname hr_ud_sum
hr_ud_sum.list <- function(x) {
  # if this is a list of packedSpatRasters, unpack it
  if (inherits(x, "PackedSpatRaster_list")) {
    x <- as.list(x)
  }
  # check that all elements of the list are SpatRaster objects
  if (!all(vapply(x, inherits, logical(1), "SpatRaster"))) {
    stop("x must be a list of SpatRaster objects")
  }
  # sum the rasters with terra
  sum_raster <- sum(terra::rast(x))
  # normalise the sum raster to have a maximum value of 1 this assumes that all
  # UDs sum to 1, so the sum of the UDs will be equal to the number of UDs
  sum_raster <- sum_raster / length(x)
  # set the name of the layer to "ud"
  names(sum_raster) <- "ud"
  return(sum_raster)
}

#' @export
#' @rdname hr_ud_sum
# Note that we have a generic method for a tibble as the hr_ud_tbl class is lost
# on group_map operations
hr_ud_sum.tbl_df <- function(x) {
  # check that this is a hr_ud_tbl
  stopifnot_hr_ud_table(x)
  
  # create a new tibble with the summed UD
  sum_tbl <- x %>% 
    dplyr::select(dplyr::all_of(
      c("method", "h", "xmin", "ymin", "xmax", "ymax", "res"))) %>%
    dplyr::distinct()
  # check that we only have one row in the sum_tbl
  if (nrow(sum_tbl) != 1) {
    stop("all UDs should have the same extent and resolution")
  }
  # we can use the hr_ud_sum.list method to sum the UDs
  sum_tbl$ud <- PackedSpatRaster_list(hr_ud_sum(x$ud))
  
  return(sum_tbl)
}

#' @export
#' @rdname hr_ud_sum
# Note that we have a generic method for a tibble as the hr_ud_tbl class is lost
# on group_map operations
hr_ud_sum.grouped_df <- function(x) {
  # check that this is a hr_ud_tbl
  stopifnot_hr_ud_table(x)

  # now we need to group_modify the tibble to sum the UDs for each group
  hr_grouped_sum <- dplyr::group_modify(
    x,
    ~ hr_ud_sum(.x)
  )
  class(hr_grouped_sum) <- c("hr_ud_tbl", class(hr_grouped_sum))
  return(hr_grouped_sum)
}


stopifnot_hr_ud_table <- function(x) {
  # check that the ud column exists
  if (!"ud" %in% colnames(x)) {
    stop("x must have a column named 'ud'")
  }
  # check that the ud column is a PackedSpatRaster_list
  if (!inherits(x$ud, "PackedSpatRaster_list")) {
    stop("x$ud must be a PackedSpatRaster_list")
  }
}