#' Resamples a tibble of tracks with a different, regular frequency
#'
#' This function resamples a tibble of tracks with a different, regular
#' frequency. The new frequency is determined by the `every` argument, which
#' takes a character string defining the interval, e.g., "1 hour", "30 mins".
#' Valid units are: "secs", "seconds", "mins", "minutes", "hours", "days",
#' "months", "years"
#'
#' The function uses the `mt_interpolate` function from `move2`.
#' @param x A tibble of tracks.
#' @param every A character string (e.g., "1 hour", "30 mins") specifying the
#'   new frequency. It can also take a POSIXct vector of times to interpolate
#'   to.
#' @return A tibble of tracks resampled at the specified frequency.
#' @export
#' @examples
#' # order time
#' shags_ordered_tt <- tt_order_time(shags_tt)
#' resampled_tt <- tt_regular_time(shags_ordered_tt, every = "20 mins")
#' resampled_tt
tt_regular_time <- function(x, every) {
  # replace minutes with mins in every if present
  every <- gsub("minutes", "mins", every)
  # same for seconds and secs
  every <- gsub("seconds", "secs", every)
  # now interpolate using move2
  return(move2::mt_interpolate(x, time = every, omit = TRUE))
}
