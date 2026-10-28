#' Create a summary of the quality of each track
#'
#' This function creates a summary of the quality of each track in a `move2`
#' object. It calculates the median sampling interval, track duration, expected
#' number of points, actual number of points, and the proportion of expected
#' points that are missing (due to gaps in track).
#'
#' Events without a location (i.e. with an empty geometry, e.g. failed fixes)
#' are not counted: the sampling interval, the duration and the number of
#' points are those of the events with a location, so that failed fixes count
#' as missing points. The duration can thus be shorter than that given by
#' [track_duration()], which uses all the events. Tracks without any event
#' with a location have 0 actual points, and `NA` for the other columns.
#' @param x A `move2` object
#' @return A tibble with one row per track (in the same order as the tracks in
#'   the metadata, see [show_meta()]) and the following columns:
#' \itemize{
#'  \item \code{<track id column>}: The track ID from \code{x}
#'  \item median_sampling_interval: The median sampling interval, in seconds
#'  (as a `units` object)
#'  \item track_duration: The duration of the track, in seconds (as a `units`
#'  object)
#'  \item expected_points: The expected number of points based on the
#'  median sampling interval
#'  \item actual_points: The actual number of points in the track
#'  \item proportion_missing: The proportion of expected points that are missing
#'  }
#' @export
#' @examples
#' track_summary_health(example_tt)
track_summary_health <- function(x) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Get the track IDs, in the same order as in the metadata
  track_ids <- show_meta(x)[[move2::mt_track_id_column(x)]]

  # Create a tibble to store the results
  results <- tibble::tibble(
    track_id = track_ids,
    median_sampling_interval = NA_real_,
    track_duration = NA_real_,
    expected_points = NA_integer_,
    actual_points = NA_integer_,
    proportion_missing = NA_real_
  )

  # Split the times of the events by track once (rather than subsetting x for
  # each track), in the order of the metadata; events without a location
  # (e.g. failed fixes) are not counted, so that they count as missing points
  located <- !sf::st_is_empty(x)
  track_times <- split(
    event_time(x)[located],
    factor(
      as.character(event_track_id(x))[located],
      levels = as.character(track_ids)
    )
  )

  # Loop through each track and calculate the summary statistics
  for (i in seq_along(track_ids)) {
    # Ensure the times are ordered within the track (as tt_order_time())
    track_time <- track_times[[i]]
    track_time <- track_time[order(track_time)]

    # A track without any location has no sampling interval or duration
    if (length(track_time) == 0) {
      results$actual_points[i] <- 0L
      next
    }

    # Calculate the median sampling interval
    sampling_intervals <- as.numeric(diff(
      track_time,
      units = "secs"
    ))
    sampling_intervals <- sampling_intervals[
      is.finite(sampling_intervals) &
        sampling_intervals > 0
    ]
    median_sampling_interval <- if (length(sampling_intervals) == 0) {
      NA_real_
    } else {
      stats::median(sampling_intervals)
    }

    # Calculate the track duration
    track_duration <- as.numeric(difftime(
      max(track_time),
      min(track_time),
      units = "secs"
    ))

    # Calculate the expected number of points
    # Calculate the actual number of points
    actual_points <- length(track_time)

    # Calculate the expected number of points
    if (is.finite(median_sampling_interval) && median_sampling_interval > 0) {
      expected_points <- round(track_duration / median_sampling_interval) + 1
      expected_points <- max(expected_points, actual_points)
    } else {
      expected_points <- actual_points
    }
    expected_points <- as.integer(expected_points)

    # Calculate the proportion of expected points that are missing
    if (expected_points > 0) {
      proportion_missing <- max(expected_points - actual_points, 0) /
        expected_points
    } else {
      proportion_missing <- 0
    }

    # Store the results in the tibble
    results$median_sampling_interval[i] <- median_sampling_interval
    results$track_duration[i] <- track_duration
    results$expected_points[i] <- expected_points
    results$actual_points[i] <- actual_points
    results$proportion_missing[i] <- proportion_missing
  }
  # the times are in seconds
  results$median_sampling_interval <- units::as_units(
    results$median_sampling_interval,
    "s"
  )
  results$track_duration <- units::as_units(results$track_duration, "s")

  # rename track_id field to the "track_id_column" in the original move2 object
  colnames(results)[which(
    colnames(results) == "track_id"
  )] <- move2::mt_track_id_column(x)

  return(results)
}
