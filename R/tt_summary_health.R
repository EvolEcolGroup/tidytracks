#' Create a summary of the quality of each track
#'
#' This function creates a summary of the quality of each track in a `move2`
#' object. It calculates the median sampling interval, track duration, expected
#' number of points, actual number of points, and the proportion of expected
#' points that are missing (due to gaps in track).
#' @param x A `move2` object
#' @return A tibble with one row per track and the following columns:
#' \itemize{
#'  \item track_id: The track ID
#'  \item median_sampling_interval: The median sampling interval in seconds
#'  \item track_duration: The duration of the track in seconds
#'  \item expected_points: The expected number of points based on the median sampling interval
#'  \item actual_points: The actual number of points in the track
#'  \item proportion_missing: The proportion of expected points that are missing
#'  }
#' @export

tt_summary_health <- function(x) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Get the track IDs
  track_ids <- unique(event_track_id(x))

  # Create a tibble to store the results
  results <- tibble::tibble(
    track_id = track_ids,
    median_sampling_interval = NA_real_,
    track_duration = NA_real_,
    expected_points = NA_integer_,
    actual_points = NA_integer_,
    proportion_missing = NA_real_
  )
  
  # Ensure the move2 object is ordered by time within each track
  x <- tt_order_time(x)

  # Loop through each track and calculate the summary statistics
  for (i in seq_along(track_ids)) {
    track_id <- track_ids[i]
    track_data <- x[event_track_id(x) == track_id, ]

    # Calculate the median sampling interval
    sampling_intervals <- diff(event_time(track_data), units = "secs")
    median_sampling_interval <- as.numeric(median(sampling_intervals))

    # Calculate the track duration
    track_duration <- as.numeric(difftime(max(event_time(track_data)), 
                               min(event_time(track_data)), units = "secs"))

    # Calculate the expected number of points
    expected_points <- round(track_duration / median_sampling_interval) + 1

    # Calculate the actual number of points
    actual_points <- nrow(track_data)

    # Calculate the percentage of expected points that are missing
    proportion_missing <- (expected_points - actual_points) / expected_points

    # Store the results in the tibble
    results$median_sampling_interval[i] <- median_sampling_interval
    results$track_duration[i] <- track_duration
    results$expected_points[i] <- expected_points
    results$actual_points[i] <- actual_points
    results$proportion_missing[i] <- proportion_missing
  }
  
  # rename track_id field to the "track_id_column" in the original move2 object
  colnames(results)[which(colnames(results) == "track_id")] <- move2::mt_track_id_column(x)

  return(results)
}