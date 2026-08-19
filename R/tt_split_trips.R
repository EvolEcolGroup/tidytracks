#' Split tracks into trips for central place foragers
#'
#' @description This function splits tracks into trips for central place
#'   foragers by identifying the trips based on a distance from the colony/nest.
#'
#' @param x A move2 object
#' @param centre_col the column name for the centre of the colony/nest of each
#'   track as found in the metadata table. Alternatively, an `sf` object of
#'   either length 1 or the same length as the number of tracks in the move2
#'   object. If a single geometry object is provided, it will be used as the
#'   centre for all tracks.
#' @param buffer_outbound the distance from the centre to define outbound trips,
#'   specified as a unit object, e.g `as_units(10000, "m")` or `as_units(10,
#'   "km")`.
#' @param buffer_inbound the distance from the centre to define inbound trips,
#'   specified as a unit object, e.g `as_units(10000, "m")` or `as_units(10,
#'   "km")`.
#' @param complete boolean, if TRUE, only complete trips (i.e. the ones that
#'   started in the outbound buffer and ended within the inbound buffer) are
#'   kept. If FALSE, all trips are kept, and events at the colony (i.e.
#'   in-between trips) are collected into a dummy trip labelled "trip_na".
#' @returns a move2 object with the trips split.
#' @export
#' @importFrom foreach %do%
#' @importFrom rlang :=

tt_split_trips <- function(
  x,
  centre_col = NULL,
  buffer_outbound = as_units(1000, "m"),
  buffer_inbound = as_units(1000, "m"),
  complete = TRUE
) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Check if centre_col is provided
  if (is.null(centre_col)) {
    stop("centre_col must be provided")
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
    centre_col <- sf::st_coordinates(centre_col)
  } else {
    stop("centre_col must be the name of a column in the metadata")
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
    units::set_units(buffer_outbound, dist_units, mode = "standard")
  )
  buffer_in_uless <- units::drop_units(
    units::set_units(buffer_inbound, dist_units, mode = "standard")
  )

  # TODO in the code above, if given an sf object with multiple rows, we should
  # demand that there is a column with the same name as the track id column in
  # the move2 object and make sure that we match up to avoid confusion

  # Get coordinates and metadata
  coords <- sf::st_coordinates(x)
  ids <- event_track_id(x)
  unique_ids <- unique(ids)

  i <- NULL # avoid global variable warning (i is used by foreach)
  # Loop through each track and split into trips
  trip_list <- foreach::foreach(i = seq_len(nrow(show_meta(x)))) %do% {
    split_one_track(
      unique_ids[i],
      coords[ids == unique_ids[i], 1],
      coords[ids == unique_ids[i], 2],
      is_lonlat = is_longlat,
      centre_x = centre_col[i, 1],
      centre_y = centre_col[i, 2],
      buffer_inbound = buffer_in_uless,
      buffer_outbound = buffer_out_uless
    )
  }

  # Combine trip IDs into a single vector
  x$trip_id <- unlist(purrr::map_depth(trip_list, 1, "trip_labels"))
  # now get the trip meta and update the track meta accordingly
  trip_meta <- purrr::map_depth(trip_list, 1, "trip_meta") %>%
    dplyr::bind_rows()
  # replace the track_id col name with the appropriate name for x
  trip_meta <- trip_meta %>%
    dplyr::rename_with(
      ~ move2::mt_track_id_column(x),
      dplyr::all_of("track_id")
    )
  # join it to the metadata
  x <- move2::mt_set_track_data(
    x,
    dplyr::full_join(show_meta(x), trip_meta, by = move2::mt_track_id_column(x))
  )
  # change the track_id_column to trip_id
  x <- move2::mt_set_track_id_column(x, "trip_id")
  # if complete, remove any trips that are not complete
  trip_type <- NULL # hack to avoid it being flagged as global in checks
  if (complete) {
    x <- x %>% filter_by_meta(trip_type == "complete")
  }

  return(x)
}

#' @title Split a track into trips
#'
#' @description an internal function that works on single tracks
#' @param label the label for the track
#' @param x the x coordinates
#' @param y the y coordinates
#' @param is_lonlat a logical indicating if the coordinates are in lonlat
#' @param centre_x the x coordinate for the central place (e.g. colony, nest)
#' @param centre_y the y coordinate for the central place (e.g. colony, nest)
#' @param buffer_outbound the buffer for outbound trips
#' @param buffer_inbound the buffer for inbound trips
#' @returns a vector with trip IDs for each event (events to remove are marked
#' as NA)
#' @keywords internal
#' @noRd
split_one_track <- function(
  label,
  x,
  y,
  is_lonlat,
  centre_x,
  centre_y,
  buffer_outbound,
  buffer_inbound
) {
  centre_x_vec <- rep(centre_x, length(x))
  centre_y_vec <- rep(centre_y, length(y))
  # Get distances between events and colony
  dist_to_centre <- dist_fast(
    x,
    y,
    centre_x_vec,
    centre_y_vec,
    longlat = is_lonlat
  )
  # define distances outside the outbound buffer
  out_events <- dist_to_centre > buffer_outbound
  # label trips
  runs <- rle(out_events)
  # now we can label the trips
  trip_labels <- rep(paste0(label, "_trip_na"), length(runs$values))
  trip_labels[(runs$values) == TRUE] <-
    paste0(paste0(label, "_trip_"), seq_len(sum((runs$values) == TRUE)))
  trip_labels_vec <- rep(trip_labels, times = runs$lengths)

  # create the metadata for the labels
  trip_meta <- tibble::tibble(
    track_id = rep(label, length(unique(trip_labels))),
    trip_id = unique(trip_labels),
    trip_type = ifelse(
      unique(trip_labels) != paste0(label, "_trip_na"),
      "complete",
      "at_centre"
    )
  )
  # check if last trip is incomplete (data ends outside colony)
  if (dist_to_centre[length(dist_to_centre)] > buffer_inbound) {
    trip_meta$trip_type[nrow(trip_meta)] <- "incomplete"
  }
  # check if first trip is incomplete (data starts outside colony)
  if (runs$values[1] == TRUE) {
    trip_meta$trip_type[1] <- "incomplete"
  }

  return(list(
    trip_labels = trip_labels_vec,
    trip_meta = trip_meta
  ))
}
