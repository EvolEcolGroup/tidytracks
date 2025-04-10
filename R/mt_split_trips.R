#' Split tracks into trips for central place foragers
#'
#' @description This function splits tracks into trips for central place foragers
#' by identifying the trips based on a distance from the colony/nest.
#'
#' @param x A move2 object
#' @param center_col the column name for the center of the colony/nest of each
#' track as found in the metadata table. Alternatively, an `sf` object of
#' either length 1 or the same length as the number of tracks in the move2 object.
#' If a single geometry object is provided, it will be used as the center for all
#' tracks.
#' @param buffer_outbound the distance from the center to define outbound trips,
#' specified as a unit object, e.g `as_units(10000, "m")` or `as_units(10, "km")`.
#' @param buffer_inbound the distance from the center to define inbound trips,
#' specified as a unit object, e.g `as_units(10000, "m")` or `as_units(10, "km")`.
#' @param complete boolean, if TRUE, only complete trips (i.e. the ones that
#' ended within the inbound buffer) are kept. If FALSE, all trips are kept, and
#' events at the colony (i.e. inbetween trips) are collected into trip
#' labelled "trip_na".
#' @returns a move2 object with the trips split.
#' @export

mt_split_trips <- function(x, center_col = NULL,
                           buffer_outbound = units::as_units(1000, "m"),
                           buffer_inbound = units::as_units(1000, "m"),
                           complete = FALSE) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Check if center_col is provided
  if (is.null(center_col)) {
    stop("center_col must be provided")
  }

  # Check if center_col is a geometry object
  if (inherits(center_col, "character")) {
    # check if it exists in the metadata
    if (!center_col %in% names(mt_show_meta(x))) {
      stop("center_col must be a column name in the metadata table")
    }
    center_col <- sf::st_coordinates(mt_show_meta(x)[[center_col]])
  } else if (inherits(center_col, "sf")) {
    center_col <- sf::st_coordinates(center_col)
    if (nrow(center_col) == 1) {
      # we have a single origin
      # copy over for as many times as n tracks
      center_col <- matrix(rep(center_col, nrow(x)), ncol = 2)
    } else if (nrow(center_col) != nrow(x)) {
      stop("center_col must be a geometry object of length 1 or the same length as the number of tracks in x")
    }
  } else {
    stop("center_col must be the name of a column in the metadata or an `sf` point object")
  }

  # Sort out units
  # set the units for the distance
  if (sf::st_is_longlat(x)) {
    is_longlat <- TRUE
    dist_units <- as_units("m")
  } else {
    is_longlat <- FALSE
    dist_units <- sf::st_crs(x)$ud_unit
  }
  # convert buffers and drop units
  buffer_out_uless <- units::drop_units(
    units::set_units(buffer_outbound, dist_units,
      mode = "standard"
    )
  )
  buffer_in_uless <- units::drop_units(
    units::set_units(buffer_inbound, dist_units,
      mode = "standard"
    )
  )



  # TODO in the code above, if given an sf object with multiple rows, we should demand
  # that there is a column with the same name as the track id column in the move 2
  # obejct and make sure that we match up to avoid confusion

  # Get coordinates and metadata
  coords <- sf::st_coordinates(x)
  ids <- event_track_id(x)
  unique_ids <- unique(ids)

  # Loop through each track and split into trips
  trip_ids <- sapply(seq_len(nrow(mt_show_meta(x))), function(i) {
    split_one_track(unique_ids[i],
      coords[ids == unique_ids[i], 1],
      coords[ids == unique_ids[i], 2],
      is_lonlat = sf::st_is_longlat(x),
      center_x = center_col[i, 1], # TODO this is wrong
      center_y = center_col[i, 2], # @TODO @BUG this is wrong
      buffer_inbound = buffer_in_uless,
      buffer_outbound = buffer_out_uless
    )
  })

  # Update metadata with trip IDs
  metadata$trip_id <- trip_ids

  if (trips_as_tracks) {
    # TODO
    stop("not implemented yet!")
    # filter out NAs
    x <- x %>% dplyr::filter(!is.na(trip_id))
  }

  return(new_move2)
}







#' @title Split a track into trips
#'
#' @description an internal function that works on single tracks
#' @param label the label for the track
#' @param x the x coordinates
#' @param y the y coordinates
#' @param is_lonlat a logical indicating if the coordinates are in lonlat
#' @param center_x the x coordinate for the central place (e.g. colony, nest)
#' @param center_y the y coordinate for the central place (e.g. colony, nest)
#' @param buffer_outbound the buffer for outbound trips
#' @param buffer_inbound the buffer for inbound trips
#' @returns a vector with trip IDs for each event (events to remove are marked
#' as NA)
#' @keywords internal
split_one_track <- function(label,
                            x, y, is_lonlat, center_x, center_y, buffer_outbound,
                            buffer_inbound) {
  center_x_vec <- rep(center_x, length(x))
  center_y_vec <- rep(center_y, length(y))
  # Get distances between events and colony
  dist_to_center <- dist_fast(x, y, center_x_vec, center_y_vec, longlat = is_lonlat)
  # define distances outside the outbound buffer
  out_events <- dist_to_center > buffer_outbound
  # define the runs of TRUE events
  #  out_events <- c(T,T,T,F,F,T,T,T,F)
  # label trips
  runs <- rle(out_events)
  # now we can label the trips
  trip_labels <- rep(paste0(label, "trip_na"), length(runs$values))
  trip_labels[(runs$values) == TRUE] <-
    paste0(paste0(label, "_trip_"), seq_len(sum((runs$values) == TRUE)))
  trip_labels <- rep(trip_labels, times = runs$lengths)

  browser()
  # @TODO mark tracks as complete or not, or na trips
  # we need to return a list with the trip labels and the trip status

  # check if the last event is within the inbound buffer
  end_of_trips <- cumsum(runs$lengths)[runs$values == TRUE]
  in_events <- dist_to_center[end_of_trips] < buffer_inbound
  # now create a table to mark the trips as complete or not
  browser()



  # browser()
  # # check if end of trips are within the inbound buffer
  # last_dists <- dist_fast(x[end_of_trips], y[end_of_trips], center_x, center_y,
  #                                longlat = is_lonlat)
  # # check if the last event is within the inbound buffer
  # last_dists <- last_dists < buffer_inbound
  # # now set runs that did not pass the test to FALSE
  # runs$values[runs$values==TRUE & last_dists==FALSE] <- FALSE



  return(trip_labels)
}
