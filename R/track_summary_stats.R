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
#' @param centre_col A geometry object or a column name in the metadata table.
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track.
#' @export

track_summary_stats <- function(x,  centre_col = NULL,
                                units_duration = units::as_units(1, "days")) {
  
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  
  # If there are still trip_na trips (at-centre locations haven't been removed)
  # then each trip is not continuous in the move2 object (the trip_na "trips"
  # occur each time the animal returns to the centre.) This breaks some of the 
  # trip summary stats code below, so we need to remove trip_na "trips" first.
  
  # Find any strings in the event_track_id(x) field ending in "_trip_na"
  trip_ids <- unique(event_track_id(x))
  trip_na_ids <- trip_ids[grepl("_trip_na$", trip_ids)]
  # if there are any _trip_na "trips", remove them from x
  if (length(trip_na_ids) > 0) {
    # remove these trip_na events from x
    x <- x[!event_track_id(x) %in% trip_na_ids, ]
  }
  rm(trip_ids, trip_na_ids)
  
  # check centre_col input
  if (!is.null(centre_col)){
    if (inherits(centre_col, "character")) {
      # check if it exists in the metadata
      if (!centre_col %in% names(show_meta(x))) {
        stop("centre_col must be a column name in the metadata table")
      }
      centre_col <- show_meta(x)[[centre_col]]
    } else if (inherits(centre_col, "sf")) {
      browser()
      stop("this option has yet to be properly implemented")
      # @TODO @BUG the code below needs changing
      centre_col <- sf::st_geometry(centre_col)
      if (nrow(centre_col) == 1) {
        # we have a single origin
        # copy over for as many times as n tracks
        centre_col <- matrix(rep(centre_col, nrow(x)), ncol = 2)
      } else if (nrow(centre_col) != nrow(show_meta(x))) {
        stop("centre_col must be a geometry object of length 1 or the same ",
             "length as the number of tracks in x")
      }
    } else {
      stop("centre_col must be the name of a column in the metadata or ",
           "an `sf` point object")
    }
  }
  
  # 1 - total duration 
  tot_duration <- track_duration(x, units = units_duration) # this is a named vector of difftimes
  # get tot_duration as a tibble with track_id field
  tot_duration_df <- tibble::tibble(track_id = names(tot_duration),
                                    tot_duration = tot_duration) # has its units still
  
  # 2 - total distance travelled
  # TODO write a cum_distance function that works on coords
  tot_distance_df <- x %>%
    dplyr::mutate(distance = move2::mt_distance(x)) %>% # add distance to next point (end-of-track is NA)
    sf::st_drop_geometry() %>% # otherwise we end up with a geometry field in the output
    dplyr::group_by(event_track_id(x)) %>% # TODO do we need to use tidyselect here?
    # dplyr::group_by(move2::mt_track_id_column(x)) %>% # TODO not sure if this is better than the line above
    dplyr::summarise(tot_distance = sum(.data[["distance"]], na.rm = TRUE)) %>%
    # dplyr::pull(tot_distance)
    # instead of extracting just tot_distance, extract as df including track_id
    dplyr::select(track_id = `event_track_id(x)`, dplyr::all_of("tot_distance")) # TODO use tidyselect here
  # tot_distance has units too
  
  # 3 - min and max lon and lat
  bboxes <- x %>%
    dplyr::group_by(event_track_id(x)) # break here to extract the group keys
  groups <- dplyr::group_keys(bboxes)
  bboxes <- bboxes %>%
    dplyr::group_map(~ sf::st_bbox(.x$geometry))
  bboxes_df <- tibble::as_tibble(do.call(rbind, bboxes)) %>%
    dplyr::mutate(max_latitude = .data$ymax,
                  min_latitude = .data$ymin,
                  max_longitude = .data$xmax,
                  min_longitude = .data$xmin) %>%
    # dplyr::select(-xmax, -xmin, -ymax, -ymin) %>%
    dplyr::select(-dplyr::all_of(c("xmax", "xmin", "ymax", "ymin"))) %>%
    dplyr::mutate(track_id = groups$`event_track_id(x)`)
  
  # 1-3 join into sum_stats table
  sum_stats <- dplyr::full_join(tot_duration_df, tot_distance_df,
                                 by = "track_id")
  sum_stats <- dplyr::full_join(sum_stats, bboxes_df,
                                 by = "track_id")
  
  # check that sum_stats has the right number of rows (number of unique track IDs)
  if (nrow(sum_stats) != length(unique(x[[move2::mt_track_id_column(x)]]))) {
    stop("There is a problem with the summary statistics. ",
         "The number of rows in the summary statistics does not match ",
         "the number of unique track IDs in x.")
  }
  
  # 4 - if centre_col is given, calculate max distance from centre and 
  #     latitude at that point
  if (!is.null(centre_col)){
    #get maximum distance between the centre and the events for each track
    centre_sums <-
      foreach::foreach(i = seq_len(nrow(show_meta(x))),
                       .combine=rbind) %do% {
      # get the track id
      track_id <- show_meta(x)[[move2::mt_track_id_column(x)]][i]
      # get the events for this track
      events <- x[event_track_id(x) == track_id, ]
      # get the centre
      centre <- centre_col[i, ]
      # calculate the distance between the centre and the events
      # TODO re-write with our distance function instead of sf::st_distance()
      dists <- sf::st_distance(events$geometry, centre)
      max_dist <- max(dists, na.rm = TRUE)
      # get lat at max dist
      lat_at_max_dist <- sf::st_coordinates(
        events$geometry[which(dists==max_dist)])[,"Y"]

      # return a dataframe of track id, maximum distance, and latitude at it.
      return(data.frame(track_id = track_id,
                        max_dist = max_dist,
                        lat_at_max_dist = lat_at_max_dist))
                       }
    
    # join into sum_stats by track_id
    sum_stats <- dplyr::full_join(sum_stats, centre_sums,
                                  by = "track_id")
    
  }
  
  # check that sum_stats has the right number of rows (number of unique track IDs)
  if (nrow(sum_stats) != length(unique(x[[move2::mt_track_id_column(x)]]))) {
    stop("There is a problem with the summary statistics. ",
         "The number of rows in the summary statistics does not match ",
         "the number of unique track IDs in x.")
  }
  
  # re-order sum_stats according to the order of track_id in the metadata
  order_track_id <- show_meta(x)[[move2::mt_track_id_column(x)]]
  sum_stats <- sum_stats[match(order_track_id, sum_stats$track_id), ]
  
  # rename track_id field to be the "track_id_column" in the original move2 object
  colnames(sum_stats)[which(colnames(sum_stats) == "track_id")] <- move2::mt_track_id_column(x)

  return(sum_stats)
}
