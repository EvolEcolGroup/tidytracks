#' Compute summary statistics for each track
#'
#' This function provides a set of summary statistics for each track. It is
#' unusual in returning a tibble of multiple variables rather than a single
#' vector. The summary statistics include the duration of the track, the
#' cumulative distance, the maximum distance from the start (or from a
#' prescribed central place), the maximum and minimum latitude and longitude.
#'
#' @param x A `move2` object
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track.
#' @export

track_summary_stats <- function(x, units_duration = units::as_units(1, "days")) {
  warning("this function is still incomplete")
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  tot_duration <- track_duration(x, units = units_duration)
  # TODO write a cum_distance function that works on coords
  cum_distance <- x %>%
    dplyr::mutate(distance = move2::mt_distance(x)) %>%
    dplyr::group_by(event_track_id(x)) %>%
    dplyr::summarise(cum_distance = sum(distance, na.rm = TRUE)) %>%
    dplyr::pull(cum_distance)
  bboxes <- x %>%
    dplyr::group_by(event_track_id(x)) %>%
    group_map(~ sf::st_bbox(.x$geometry))
  bboxes <- tibble::as_tibble(do.call(rbind, bboxes)) %>%
    dplyr::mutate(max_latitude = ymax,
                  min_latitude = ymin,
                  max_longitude = xmax,
                  min_longitude = xmin) %>%
    dplyr::select(-xmax, -xmin, -ymax, -ymin)
  sum_stats <- dplyr::bind_cols(
    tibble::tibble(tot_duration = tot_duration,
                   cum_distance = cum_distance),
    bboxes)

  return(sum_stats)
}
