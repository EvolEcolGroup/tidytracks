#' Split tracks into trips for central place foragers
#'
#' @description This function splits tracks into trips for central place
#'   foragers, based on when the animal moves away from, and returns to, the
#'   colony/nest (the centre). A trip is an excursion beyond `buffer_trip`,
#'   with no minimum duration (a single location beyond it is a trip); gaps in
#'   the data do not split trips.
#'
#'   Trips are classified as complete or incomplete. If the track starts or
#'   ends beyond `buffer_trip`, i.e. during a trip, that trip is incomplete
#'   (e.g. the logger only started recording after the animal had left, or its
#'   battery failed before the animal returned). So only the first and last
#'   trips of a track can be incomplete, and a track that starts and ends at
#'   the centre only has complete trips.
#'
#'   `buffer_complete` can make this check more tolerant. If it is larger than
#'   `buffer_trip`, it is used instead, so a trip is only incomplete if the
#'   track starts or ends beyond `buffer_complete`. For example, with
#'   `buffer_trip` = 10 km and `buffer_complete` = 50 km, a track that
#'   starts 30 km from the centre has a complete first trip. If
#'   `buffer_complete` is the same as, or smaller than, `buffer_trip`, it has
#'   no effect.
#'
#' @details Events without a location (empty geometries) are assigned to the
#'   trip of the preceding event with a location (or of the following one, at
#'   the start of a track), so they only join a trip when they fall between two
#'   of its events. In particular, events without a location after a return
#'   location added by `boundary_events` stay at the centre.
#'
#' @param x A move2 object
#' @param centre_col character string, the name of the column in the metadata
#'   table that contains the centre of the colony/nest for each track. This
#'   column must be of class `sfc_POINT` and should have a valid coordinate
#'   reference system (CRS) specified. The function `sf_point_col()` can be used
#'   to create this column.
#' @param buffer_trip the distance from the centre that delimits trips: a
#'   trip starts when the animal moves further than this distance from the
#'   centre, and ends when it comes back within it. Specified as a unit object,
#'   e.g `as_units(10000, "m")` or `as_units(10, "km")`.
#' @param buffer_complete a distance from the centre, usually the same as or
#'   larger than `buffer_trip`, within which a track can start or end during
#'   a trip and that trip still be classified as complete (see Description). It
#'   has no effect if it is the same as, or smaller than, `buffer_trip`.
#'   Specified as a unit object, e.g `as_units(10000, "m")` or `as_units(10,
#'   "km")`.
#' @param complete boolean, if TRUE, only complete trips are kept. If FALSE,
#'   all trips are kept, and events at the colony (i.e. in-between trips) are
#'   collected into a dummy trip labelled "trip_na".
#' @param boundary_events which locations at the centre, i.e. within
#'   `buffer_trip`, are also included in the trips, so that the trips
#'   connect to the centre:
#'   * `"none"` (the default): none, trips only include the events outside
#'   `buffer_trip`.
#'   * `"return"`: each trip that ends back at the centre also includes the
#'   location that ends it, i.e. its first location back within
#'   `buffer_trip`, as the trips of `tripSplit()` in the `track2KBA`
#'   package do.
#'   * `"departure"`: each trip that does not start the track also includes
#'   its departure location, i.e. the last location within `buffer_trip`
#'   before it.
#'   * `"both"`: both of the above. If a single location at the centre
#'   separates two trips, it is the return of the earlier trip, and the later
#'   trip has no departure location.
#'
#'   Trips that start or end the track have no departure or return location.
#' @param buffer_outbound,buffer_inbound Deprecated, use `buffer_trip` and
#'   `buffer_complete` instead (see [tidytracks-deprecated]). The old names
#'   still work for backwards compatibility, but they issue a warning and will
#'   be removed in a future release.
#' @returns The `move2` object, modified: each track is split into its
#'   foraging trips, and each trip is treated as a separate track:
#'   - The events have a new column, `trip_id`, which becomes the track id
#'     column. The original track id column is kept, so trips can still be
#'     grouped by track.
#'   - The metadata has one row per trip, with the columns of its original
#'     track (repeated for each of its trips), and new columns `trip_id`
#'     (linking to events table `trip_id`), and `trip_type`:
#'     * `"complete"`: the whole trip was recorded.
#'     * `"incomplete"`: the track starts or ends during the trip (beyond
#'       `buffer_complete`, if that is larger than `buffer_trip`), so part
#'       of the trip is missing.
#'     * `"at_centre"`: not a trip, but all the events of the track at the
#'       centre (before, between and after its trips), in a single row per
#'       track.
#'
#'   Trips are labelled `<track id>_trip_1`, `<track id>_trip_2`, ... in time
#'   order, and `<track id>_trip_na` for the events at the centre. With
#'   `complete = TRUE` (the default), only complete trips are kept, so tracks
#'   without a complete trip are dropped, and the numbering can have gaps
#'   (e.g. if the first trip of a track is incomplete, its first trip kept is
#'   `<track id>_trip_2`).
#' @export
#' @importFrom foreach %do%
#' @importFrom rlang :=
#' @examples
#' # First, add a sf point column to metadata giving nest location
#' show_meta(example_tt) <- show_meta(example_tt) %>%
#'   dplyr::mutate(nest_location = sf_point_col(nest_lon, nest_lat, crs = 4326))
#' # Now split the tracks into trips
#' example_tt_split <- tt_split_trips(
#'   x = example_tt,
#'   centre_col = "nest_location",
#'   buffer_trip = as_units(1, "km"),
#'   buffer_complete = as_units(1, "km"),
#'   complete = FALSE
#' )
#' # Now the unit of tracking is `trip_id` column
#' move2::mt_track_id_column(example_tt_split)
#' # Three incomplete trips were identified
#' show_meta(example_tt_split) %>%
#'   dplyr::group_by(track_id, trip_id, trip_type) %>%
#'   dplyr::summarise(.groups = "drop")
tt_split_trips <- function(
  x,
  centre_col = NULL,
  buffer_trip = as_units(1000, "m"),
  buffer_complete = as_units(1000, "m"),
  complete = TRUE,
  boundary_events = c("none", "return", "departure", "both"),
  buffer_outbound = NULL,
  buffer_inbound = NULL
) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # deprecated argument names for backward compatibility: buffer_outbound is
  # now buffer_trip
  if (!is.null(buffer_outbound)) {
    # giving both names for the same buffer is ambiguous
    if (!missing(buffer_trip)) {
      stop("Use only one of buffer_trip and buffer_outbound (deprecated)")
    }
    warning(
      "The `buffer_outbound` argument of tt_split_trips() has been renamed ",
      "`buffer_trip`. The old name still works for backwards compatibility, ",
      "but it issues a warning and will be removed in a future release. ",
      "Please use `buffer_trip` instead.",
      call. = FALSE
    )
    # use the value given to the old name
    buffer_trip <- buffer_outbound
  }
  # buffer_inbound is now buffer_complete
  if (!is.null(buffer_inbound)) {
    # giving both names for the same buffer is ambiguous
    if (!missing(buffer_complete)) {
      stop("Use only one of buffer_complete and buffer_inbound (deprecated)")
    }
    warning(
      "The `buffer_inbound` argument of tt_split_trips() has been renamed ",
      "`buffer_complete`. The old name still works for backwards ",
      "compatibility, but it issues a warning and will be removed in a future ",
      "release. Please use `buffer_complete` instead.",
      call. = FALSE
    )
    # use the value given to the old name
    buffer_complete <- buffer_inbound
  }

  boundary_choices <- c("none", "return", "departure", "both")
  if (identical(boundary_events, boundary_choices)) {
    boundary_events <- "none"
  }
  if (
    !is.character(boundary_events) ||
      length(boundary_events) != 1 ||
      !boundary_events %in% boundary_choices
  ) {
    stop(
      'boundary_events must be one of "none", "return", "departure" or "both"'
    )
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
    if (any(sf::st_is_empty(centre_col), na.rm = TRUE)) {
      stop("centre_col must not contain empty geometries")
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
  buffer_trip_uless <- units::drop_units(
    units::set_units(buffer_trip, dist_units, mode = "standard")
  )
  buffer_complete_uless <- units::drop_units(
    units::set_units(buffer_complete, dist_units, mode = "standard")
  )

  # Get coordinates, track ids and times of the events
  coords <- sf::st_coordinates(x)
  ids <- as.character(event_track_id(x))
  times <- event_time(x)
  # the centres are in the same order as the tracks in the metadata, which can
  # differ from the order of the tracks in the events table
  meta_ids <- show_meta(x)[[move2::mt_track_id_column(x)]]
  # the events of each track (splitting the rows once is much faster, with
  # many tracks, than finding the rows of each track among all the rows)
  rows_by_track <- split(
    seq_along(ids),
    factor(ids, levels = unique(as.character(meta_ids)))
  )

  i <- NULL # avoid global variable warning (i is used by foreach)
  # Loop through each track and split its events, in time order, into trips
  trip_list <- foreach::foreach(i = seq_along(meta_ids)) %do% {
    track_rows <- rows_by_track[[as.character(meta_ids[i])]]
    track_rows <- track_rows[order(times[track_rows])]
    trips <- split_one_track(
      meta_ids[i],
      coords[track_rows, 1],
      coords[track_rows, 2],
      is_lonlat = is_longlat,
      centre_x = centre_col[i, 1],
      centre_y = centre_col[i, 2],
      buffer_trip = buffer_trip_uless,
      buffer_complete = buffer_complete_uless,
      boundary_events = boundary_events
    )
    trips$track_rows <- track_rows
    trips
  }

  # Assign the trip IDs back to the events they were computed for (events are
  # not required to be grouped by track or ordered by time)
  trip_ids <- character(nrow(x))
  for (trips in trip_list) {
    trip_ids[trips$track_rows] <- trips$trip_labels
  }
  x$trip_id <- trip_ids
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
#' @param x the x coordinates, in time order
#' @param y the y coordinates, in time order
#' @param is_lonlat a logical indicating if the coordinates are in lonlat
#' @param centre_x the x coordinate for the central place (e.g. colony, nest)
#' @param centre_y the y coordinate for the central place (e.g. colony, nest)
#' @param buffer_trip the buffer that delimits trips
#' @param buffer_complete the buffer within which a track can start or end
#'   during a trip and that trip still be complete
#' @param boundary_events one of "none", "return", "departure" or "both", the
#'   locations at the centre (just before and/or just after each trip) to
#'   include in the trips
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
  buffer_trip,
  buffer_complete,
  boundary_events
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
  # define distances outside the trip buffer
  out_events <- dist_to_centre > buffer_trip
  # events without a location (empty geometries) take the state of the
  # preceding located event (or of the following one, at the start of the
  # track); a track without any location is considered to be at the centre
  located <- which(!is.na(out_events))
  if (length(located) == 0) {
    out_events[] <- FALSE
  } else {
    nearest <- pmax(findInterval(seq_along(out_events), located), 1)
    out_events <- out_events[located[nearest]]
  }
  # label trips
  runs <- rle(out_events)
  # now we can label the trips
  trip_labels <- rep(paste0(label, "_trip_na"), length(runs$values))
  trip_labels[(runs$values) == TRUE] <-
    paste0(paste0(label, "_trip_"), seq_len(sum((runs$values) == TRUE)))
  trip_labels_vec <- rep(trip_labels, times = runs$lengths)
  trip_ends <- cumsum(runs$lengths)[runs$values]
  trip_starts <- trip_ends - runs$lengths[runs$values] + 1
  # add to each trip that starts after the track does its departure location,
  # i.e. the last location within the trip buffer before the trip, and the
  # events without a location between it and the trip (every run of events at
  # the centre has a location, as events without a location take the state of
  # a located event)
  if (boundary_events %in% c("departure", "both")) {
    trip_starts <- trip_starts[trip_starts > 1]
    departures <- located[findInterval(trip_starts - 1, located)]
    # with both, a single location at the centre between two trips is the
    # return of the earlier trip, so the later trip has no departure, and the
    # events without a location in between, which are not between two events
    # of either trip, stay at the centre
    if (boundary_events == "both") {
      has_departure <- !departures %in% (trip_ends + 1)
      trip_starts <- trip_starts[has_departure]
      departures <- departures[has_departure]
    }
    trip_labels_vec[sequence(trip_starts - departures, from = departures)] <-
      rep(trip_labels_vec[trip_starts], times = trip_starts - departures)
  }
  # add to each trip that ends before the track does the event after its last
  # one, which is the first location back within the trip buffer (events
  # without a location take the state of the preceding location, so the event
  # after a trip always has a location)
  if (boundary_events %in% c("return", "both")) {
    trip_ends <- trip_ends[trip_ends < length(out_events)]
    trip_labels_vec[trip_ends + 1] <- trip_labels_vec[trip_ends]
  }

  # create the metadata for the labels
  # (tibble::new_tibble() rather than tibble::tibble(), whose checks take
  # about a millisecond, i.e. most of the time taken by a short track); the
  # labels are taken from the events, as the first location back at the
  # centre might have been the only event at the centre
  trip_ids <- unique(trip_labels_vec)
  trip_meta <- tibble::new_tibble(
    list(
      track_id = rep(label, length(trip_ids)),
      trip_id = trip_ids,
      trip_type = ifelse(
        trip_ids != paste0(label, "_trip_na"),
        "complete",
        "at_centre"
      )
    ),
    nrow = length(trip_ids)
  )
  # check if last trip is incomplete (the track ends during the trip, outside
  # the completeness buffer; if the track ends with a trip, its last location
  # is outside the trip buffer, so the track has a location); a track that
  # ends at the centre, even beyond the completeness buffer, has no incomplete
  # last trip
  if (
    utils::tail(runs$values, 1) &&
      dist_to_centre[utils::tail(located, 1)] > buffer_complete
  ) {
    n_trips <- sum(runs$values)
    last_trip <- trip_meta$trip_id == paste0(label, "_trip_", n_trips)
    trip_meta$trip_type[last_trip] <- "incomplete"
  }
  # check if first trip is incomplete (data starts outside the completeness
  # buffer; if the track starts with a trip, its first location is outside the
  # trip buffer, so the track has a location)
  if (runs$values[1] && dist_to_centre[located[1]] > buffer_complete) {
    trip_meta$trip_type[1] <- "incomplete"
  }

  return(list(
    trip_labels = trip_labels_vec,
    trip_meta = trip_meta
  ))
}
