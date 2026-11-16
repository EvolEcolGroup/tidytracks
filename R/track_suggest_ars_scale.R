#' Suggest the scale of area-restricted search of each track
#'
#' This function suggests, for each track (or group), the spatial scale of
#' area-restricted search (ARS), as the radius of a peak of the variance of the
#' log of the first passage time (see [track_fpt_profile()]).
#'
#' The suggestion is purely data-driven, and can strongly depend on `method`:
#' inspect the profile with [ggplot2::autoplot()], and check the suggestion
#' against what is known about the species. Noise can produce small peaks,
#' especially with many radii and at the largest radii, which are based on few
#' events. Not all species use ARS.
#'
#' To use the suggestion as the bandwidth of [hr_tt_kde()], note that the
#' bandwidth is the standard deviation of a Gaussian kernel rather than the
#' radius of a circle: a kernel with a bandwidth equal to the radius has 39% of
#' its mass within that radius, and 95% of its mass within 2.45 times that
#' radius.
#'
#' @param x A move2 object, as for [track_fpt_profile()], or a tibble of class
#'   `fpt_profile_tbl`, as returned by it.
#' @param radii The radii, as for [track_fpt_profile()]. Only used if `x` is a
#'   move2 object.
#' @param method The peak to select if there are several: "first" (the default;
#'   the one at the smallest radius), "max" (the highest), or "steep" (the one
#'   around which the variance changes the most).
#' @param peak_width The number of radii on either side of a peak that must have
#'   a variance that is not higher than the peak. The default is 1.
#' @param units The units of the returned scales, as a `units` object. The
#'   default is metres (`as_units("m")`).
#' @returns A `units` vector with the suggested scale for each track (or group),
#'   named by its id and in the order of [track_fpt_profile()], with `NA` if no
#'   peak is found.
#' @seealso [event_fpt()], [track_fpt_profile()]
#' @export
#' @examples
#' x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
#' track_suggest_ars_scale(x, radii = as_units(c(50, 100, 200), "km"))
track_suggest_ars_scale <- function(
  x,
  radii = NULL,
  method = c("first", "max", "steep"),
  peak_width = 1,
  units = as_units("m")
) {
  method <- match.arg(method)
  if (!inherits(units, "units")) {
    stop("units must be a units object: e.g. as_units('km')")
  }
  if (
    !is.numeric(peak_width) ||
      length(peak_width) != 1 ||
      !is.finite(peak_width) ||
      peak_width < 1 ||
      peak_width != round(peak_width)
  ) {
    stop("peak_width must be a positive whole number")
  }
  profile <- if (inherits(x, "fpt_profile_tbl")) {
    x
  } else {
    track_fpt_profile(x, radii = radii)
  }
  radius <- units::set_units(profile$radius, units, mode = "standard")
  # in the order of the profile, rather than sorted
  ids <- as.character(profile[[1]])
  rows_by_id <- split(seq_along(ids), factor(ids, levels = unique(ids)))
  scales <- vapply(
    rows_by_id,
    function(rows) {
      peak <- fpt_peak(profile$var_log_fpt[rows], method, peak_width)
      # the radius of the peak, rather than its position among the radii
      as.numeric(radius[rows])[peak]
    },
    numeric(1)
  )
  units::set_units(scales, units, mode = "standard")
}

#' Find the peak of a profile
#'
#' A peak is a value higher than the values next to it, and not lower than any
#' value within `width` positions of it. Values that differ by less than their
#' rounding error are taken to be equal, so a flat profile has no peak: e.g.
#' for radii smaller than all the steps of a track, the FPT is proportional to
#' the radius, so the variance of its log is the same at all radii, but for
#' differences of about 1e-15 that are only rounding.
#'
#' @param variance A numeric vector, for radii in increasing order; it can have
#'   missing values.
#' @param method "first", "max" or "steep".
#' @param width The number of positions on either side of a peak to check.
#' @returns The position of the selected peak, or `NA_integer_` if there is
#'   none.
#' @keywords internal
#' @noRd
fpt_peak <- function(variance, method, width) {
  n <- length(variance)
  # the variance of the log of the FPT has no units, so an absolute tolerance
  # of about 1e-8 is used for variances up to 1, and a relative one above
  tolerance <- sqrt(.Machine$double.eps) *
    max(1, abs(variance), na.rm = TRUE)
  window <- function(i, from, to) {
    seq(max(from, 1), min(to, n))
  }
  is_peak <- function(i) {
    if (anyNA(variance[c(i - 1, i, i + 1)])) {
      return(FALSE)
    }
    # the peak must be higher than both neighbours by more than rounding
    if (
      variance[i] - variance[i - 1] <= tolerance ||
        variance[i] - variance[i + 1] <= tolerance
    ) {
      return(FALSE)
    }
    # and not lower than any value in the window, beyond rounding
    all(
      variance[window(i, i - width, i + width)] <= variance[i] + tolerance,
      na.rm = TRUE
    )
  }
  candidates <- if (n >= 3) seq(2, n - 1) else integer(0)
  peaks <- candidates[vapply(candidates, is_peak, logical(1))]
  if (length(peaks) == 0) {
    return(NA_integer_)
  }
  switch(
    method,
    first = peaks[1],
    max = peaks[which.max(variance[peaks])],
    steep = {
      # how much the variance rises to the peak, and falls after it
      steepness <- vapply(
        peaks,
        function(i) {
          sum(abs(diff(variance[window(i, i - width, i)])), na.rm = TRUE) +
            sum(abs(diff(variance[window(i, i, i + width)])), na.rm = TRUE)
        },
        numeric(1)
      )
      peaks[which.max(steepness)]
    }
  )
}
