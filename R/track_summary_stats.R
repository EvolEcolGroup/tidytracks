#' Compute summary statistics for each track
#'
#' This function provides a set of summary statistics for each track. It is
#' unusual in returning a tibble of multiple variables rather than a single
#' vector. The summary statistics include the duration of the track, the
#' cumulative distance, the maximum and minimum latitude and longitude of
#' the total track, and, if a central place location is provided, the maximum
#' distance that location,  and the latitude at the most distant point from
#' the central place location
#'
#' @param x A `move2` object
#' @param center_col A geometry object or a column name in the metadata table.
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track.
#' @export

track_summary_stats <- function(x,  center_col = NULL,
                                units_duration = units::as_units(1, "days")) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  if (!is.null(center_col)){
    if (inherits(center_col, "character")) {
      # check if it exists in the metadata
      if (!center_col %in% names(show_meta(x))) {
        stop("center_col must be a column name in the metadata table")
      }
      center_col <- show_meta(x)[[center_col]]
    } else if (inherits(center_col, "sf")) {
      browser()
      stop("this option has yet to be properly implemented")
      # @TODO @BUG the code below needs changing
      center_col <- sf::st_geometry(center_col)
      if (nrow(center_col) == 1) {
        # we have a single origin
        # copy over for as many times as n tracks
        center_col <- matrix(rep(center_col, nrow(x)), ncol = 2)
      } else if (nrow(center_col) != nrow(show_meta(x))) {
        stop("center_col must be a geometry object of length 1 or the same ",
             "length as the number of tracks in x")
      }
    } else {
      stop("center_col must be the name of a column in the metadata or ",
           "an `sf` point object")
    }
  }

  tot_duration <- track_duration(x, units = units_duration)
  # TODO write a cum_distance function that works on coords
  tot_distance <- x %>%
    dplyr::mutate(distance = move2::mt_distance(x)) %>%
    dplyr::group_by(event_track_id(x)) %>%
    dplyr::summarise(tot_distance = sum(distance, na.rm = TRUE)) %>%
    dplyr::pull(tot_distance)
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
                   tot_distance = tot_distance),
    bboxes)
  if (!is.null(center_col)){
    #get maximum distance between the center and the events for each track
    center_sums <-
      foreach::foreach(i = seq_len(nrow(show_meta(x))),
                       .combine=rbind) %do% {
      # get the track id
      track_id <- show_meta(x)[[move2::mt_track_id_column(x)]][i]
      # get the events for this track
      events <- x[event_track_id(x) == track_id, ]
      # get the center
      center <- center_col[i, ]
      # calculate the distance between the center and the events
      dists <- sf::st_distance(events$geometry, center)
      max_dist <- max(dists, na.rm = TRUE)
      # get lat at max dist
      lat_at_max_dist <- sf::st_coordinates(
        events$geometry[which(dists==max_dist)])[,"Y"]

      # return the maximum distance
      return(c(unclass(max_dist), lat_at_max_dist))
                       }
    sum_stats$max_dist_center <- as_units(center_sums[,1], units(sum_stats$tot_distance))
    sum_stats$lat_at_max_dist_center <- center_sums[,2]
  }

  return(sum_stats)
}
