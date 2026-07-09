#' Measure the time interval between pairs of consecutive events within each
#' track
#'
#' This function measures the interval (i.e. time interval) between adjacent
#' pairs of consecutive events within each track. It returns a vector of
#' intervals of the same length as the number of events in `x`, with the value
#' for the last event of each track padded with an NA.
#'
#' This is a wrapper around `move2::mt_time_lags()`. Note that the timestamps of
#' events have to be ordered for this function to work correctly (you can use
#' [tt_order_time()] to order your tibble of tracks.
#'
#' @param x A move2 object
#' @param units Optional, the time units (as `character`, `symbolic_units` or
#'   `units`) used to represent the intervals. It defaults to the units of the
#'   input data.
#' @returns a vector of time intervals of the same length as the number of
#'   events in `x`, with the last value set to NA for each track.
#' @export
#'
#' @examples
#' event_interval(example_tt)
#' event_interval(example_tt, units = "hours")
#'

event_interval <- move2::mt_time_lags
