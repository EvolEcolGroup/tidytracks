#' Compute summary statistics for each track
#'
#' This function provides a set of summary statistics for each track. It is
#' unusual in returning a tibble of multiple variables rather than a single
#' vector. The summary statistics include the duration of the track, the
#' cumulative distance, the maximum and minimum latitude and longitude of the
#' total track, and, if a central place location is provided, the maximum
#' distance that location, and the latitude at the most distant point from the
#' central place location
#'
#' @param x A `move2` object
#' @param centre_col The name of an sf point column (usually added with
#'   [sf_point_col()]) in the metadata table. If let to NULL, variables
#'   related to a central place location will not be calculated.
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track. The columns are:
#' \itemize{
#'  \item \code{<track id column>}: The track ID from \code{x}
#'  \item tot_duration: The total duration of the track in the specified units
#'  \item tot_distance: The total distance travelled in the track in metres
#'  \item max_latitude: The maximum latitude of the track
#'  \item min_latitude: The minimum latitude of the track
#'  \item max_longitude: The maximum longitude of the track
#'  \item min_longitude: The minimum longitude of the track
#'  \item max_dist_centre: The maximum distance from the central place location in
#'  column `centre_col` (if provided) in metres
#'  \item lat_at_max_dist_centre: The latitude at the point of maximum distance from
#'  the central place location (if provided)
#'  \item lon_at_max_dist_centre: The longitude at the point of maximum
#'  distance from the central place location (if provided)
#'  }
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
  
  # check centre_col input
    if (inherits(centre_col, "character")) {
      # check if it exists in the metadata
      if (!centre_col %in% names(show_meta(x))) {
        stop("centre_col must be a column name in the metadata table")
      }
      centre_col <- show_meta(x)[[centre_col]]
      # cehck that this is an `sfc_POINT` column
      if (!inherits(centre_col, "sfc_POINT")) {
        stop("centre_col must be a `sfc_POINT` column in the metadata table")
      }
      # check that we have a crs for this column
      if (is.na(sf::st_crs(centre_col))) {
        stop("centre_col must have a crs specified")
      }
      # project the centre_col to the same crs as x
      if (!(sf::st_crs(centre_col) == sf::st_crs(x))) {
        centre_col <- sf::st_transform(centre_col, sf::st_crs(x))
      }                                                
    } else {
      stop("centre_col must be the name of a column in the metadata")
    }

  # 1 - total duration 
  tot_duration <- track_duration(x, units = units_duration) # this is a named vector of difftimes
  # get tot_duration as a tibble with track_id field
  tot_duration_df <- tibble::tibble(track_id = names(tot_duration),
                                    tot_duration = tot_duration) # has its units still
  
  # 2 - total distance travelled
  # TODO write a cum_distance function that works on coords
  .group_var <- move2::mt_track_id_column(x)
  tot_distance_df <- x %>%
    dplyr::mutate(distance = move2::mt_distance(x)) %>% # add distance to next point (end-of-track is NA)
    sf::st_drop_geometry() %>% # otherwise we end up with a geometry field in the output
    dplyr::group_by(.data[[.group_var]]) %>% # group by the track id field (whatever it's called)
    dplyr::summarise(tot_distance = sum(.data[["distance"]], na.rm = TRUE)) %>%
    # instead of extracting just tot_distance, extract as df including track_id
    dplyr::select(track_id = dplyr::all_of(.group_var), dplyr::all_of("tot_distance"))
  # tot_distance has units too
  
  # 3 - min and max lon and lat
  bboxes <- x %>%
    dplyr::group_by(.data[[.group_var]]) # break here to extract the group keys
  groups <- dplyr::group_keys(bboxes)
  bboxes <- bboxes %>%
    dplyr::group_map(~ sf::st_bbox(.x$geometry))
  bboxes_df <- tibble::as_tibble(do.call(rbind, bboxes)) %>%
    dplyr::mutate(max_latitude = .data$ymax,
                  min_latitude = .data$ymin,
                  max_longitude = .data$xmax,
                  min_longitude = .data$xmin) %>%
    dplyr::select(-dplyr::all_of(c("xmax", "xmin", "ymax", "ymin"))) %>%
    dplyr::mutate(track_id = groups[[.group_var]])
  
  # 1-3 join into sum_stats table
  sum_stats <- dplyr::full_join(tot_duration_df, tot_distance_df,
                                 by = "track_id")
  sum_stats <- dplyr::full_join(sum_stats, bboxes_df,
                                 by = "track_id")
  
  # 4 - if centre_col is given, calculate max distance from centre and 
  #     latitude at that point
  if (!is.null(centre_col)){
    # appease R CMD check - could have used a globalVariable for this instead
    i_foreach <- NULL
    # get maximum distance between the centre and the events for each track
    centre_sums <-
      foreach::foreach(i_foreach = seq_len(nrow(show_meta(x))),
                       .combine=rbind) %do% {
      # get the track id
      track_id <- show_meta(x)[[move2::mt_track_id_column(x)]][i_foreach]
      # get the events for this track
      events <- x[event_track_id(x) == track_id, ]
      # get the centre
      centre <- centre_col[i_foreach, ]
      # calculate the distance between the centre and the events
      # TODO re-write with our distance function instead of sf::st_distance()
      dists <- sf::st_distance(events$geometry, centre)
      max_dist <- max(dists, na.rm = TRUE)
      # get lat and lon at max dist
      lat_at_max_dist <- sf::st_coordinates(
        events$geometry[which(dists==max_dist)[1]])[,"Y"]
      lon_at_max_dist <- sf::st_coordinates(
        events$geometry[which(dists==max_dist)[1]])[,"X"]

      # return a dataframe of track id, maximum distance, and lat/lon at it.
      return(data.frame(track_id = track_id,
                        max_dist_centre = max_dist,
                        lat_at_max_dist_centre = lat_at_max_dist,
                        lon_at_max_dist_centre = lon_at_max_dist))
                       }
    
    # join into sum_stats by track_id
    sum_stats <- dplyr::full_join(sum_stats, centre_sums,
                                  by = "track_id")
    
  }
  
  # check that sum_stats has the right number of rows (number of unique track IDs)
  # This is a sanity check, it should never happen.
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
