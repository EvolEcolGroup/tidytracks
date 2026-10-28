#' Compute summary statistics for each track
#'
#' This function provides a set of summary statistics for each track. It is
#' unusual in returning a tibble of multiple variables rather than a single
#' vector. The summary statistics include the duration of the track, the
#' cumulative distance along the track, the maximum and minimum latitude and
#' longitude of the track, and, if a central place location is provided, the
#' maximum distance from that location, and the latitude and longitude at the
#' most distant point from that location.
#'
#' @details
#' Note that the central place location is often not part of the track.
#' This means that under certain circumstances (e.g. very large buffers used in
#' trip splitting), the total distance travelled along the track may be shorter
#' than the maximum distance from the central location. In this case, you could
#' consider either using a smaller buffer for trip splitting, or manually adding
#' an at-colony point at the start and end of the track.
#'
#' The units for distance, latitude, and longitude are taken from the
#' projection. The units for duration are specified by the `units_duration`
#' argument.
#'
#' @param x A `move2` object
#' @param centre_col The name of an sf point column (usually added with
#'   [sf_point_col()]) in the metadata table. If left as `NULL`, the first
#'   location of each track (i.e. the starting point) is used as the centre.
#' @param units_duration The units to use for the duration. Default is "days".
#' @return A tibble of summary statistics, with one row per track. The columns
#'   are:
#' \itemize{
#'  \item \code{<track id column>}: The track ID from \code{x}
#'  \item `tot_duration`: The total duration of the track in the specified units
#'  \item `tot_distance`: The total distance travelled in the track
#'  \item `max_latitude`: The maximum latitude of the track
#'  \item `min_latitude`: The minimum latitude of the track
#'  \item `max_longitude`: The maximum longitude of the track
#'  \item `min_longitude`: The minimum longitude of the track
#'  \item `max_dist_centre`: The maximum distance from the central place
#'  location in column `centre_col` (or the starting point)
#'  \item `lat_at_max_dist_centre`: The latitude at the point of maximum
#'  distance from the central place location (or the starting point)
#'  \item `lon_at_max_dist_centre`: The longitude at the point of maximum
#'  distance from the central place location (or the starting point)
#'  }
#' @export
#' @examples
#' track_summary_stats(example_tt)
track_summary_stats <- function(
  x,
  centre_col = NULL,
  units_duration = as_units(1, "days")
) {
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
  .group_var <- move2::mt_track_id_column(x)
  # the track ids in the order of the metadata, and the index of the track of
  # each event among them; all the statistics are computed for all the
  # tracks at once, in the order of the metadata
  track_ids <- show_meta(x)[[.group_var]]
  track_index <- match(
    as.character(event_track_id(x)),
    as.character(track_ids)
  )
  # the coordinates of the events (NA for events without a location)
  coords <- sf::st_coordinates(sf::st_geometry(x))

  # check centre_col input
  if (is.null(centre_col)) {
    # the first location is the first event with a location (events without
    # a location have an empty geometry): sort the located events by track
    # and time (order() is stable, so ties keep the order of the events),
    # and take the first event of each track
    located <- which(!sf::st_is_empty(x))
    located <- located[order(track_index[located], event_time(x)[located])]
    first_located <- located[!duplicated(track_index[located])]
    # in the order of the metadata; tracks without any location get an
    # empty centre
    centre_col <- sf::st_geometry(x)[
      first_located[match(seq_along(track_ids), track_index[first_located])]
    ]
  } else if (inherits(centre_col, "character")) {
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
  # this is a named vector of difftimes, in the order of the metadata
  tot_duration <- track_duration(x, units = units_duration)

  # 2 - total distance travelled
  # this is a named vector of distances, in the order of the metadata and in
  # the units of the projection (metres for geographic coordinates), as
  # returned by sf::st_distance()
  dist_units <- units(sf::st_distance(sf::st_geometry(x)[1]))
  tot_distance <- track_tot_distance( # nolint: object_usage_linter.
    x,
    units = as_units(1, dist_units)
  )

  # 3 - min and max lon and lat
  # the coordinates of each track, in the order of the metadata
  track_factor <- factor(track_index, levels = seq_along(track_ids))
  # summarise the coordinates on one axis of each track with `fun`, ignoring
  # the events without a location (NA for tracks without any location)
  summarise_coords <- function(axis, fun) {
    unname(vapply(
      split(coords[, axis], track_factor),
      function(track_coords) {
        track_coords <- track_coords[!is.na(track_coords)]
        if (length(track_coords) > 0) fun(track_coords) else NA_real_
      },
      numeric(1)
    ))
  }

  # 4 - max distance from the centre and latitude and longitude at that point
  # calculate the distance between the centre and the events with
  # dist_fast(), as for the distances along the track (i.e. geodesic for
  # geographic coordinates, whatever the s2 setting), in the units of the
  # projection
  centre_coords <- sf::st_coordinates(centre_col)
  dists <- dist_fast(
    coords[, "X"],
    coords[, "Y"],
    centre_coords[track_index, "X"],
    centre_coords[track_index, "Y"],
    longlat = sf::st_is_longlat(x)
  )
  # the first event at the maximum distance of each track: sort the events by
  # track and decreasing distance (NA last; order() is stable, so ties keep
  # the order of the events), and take the first event of each track
  by_dist <- order(track_index, -dists)
  i_max <- by_dist[!duplicated(track_index[by_dist])]
  # in the order of the metadata
  i_max <- i_max[match(seq_along(track_ids), track_index[i_max])]
  # NA if no distance is known, i.e. if the track or its centre has no
  # location
  i_max[is.na(dists[i_max])] <- NA

  # 1-4 combine into sum_stats table, in the order of the metadata (taking
  # the track ids from the metadata keeps their type, e.g. integer)
  sum_stats <- tibble::tibble(
    track_id = track_ids,
    tot_duration = tot_duration, # has its units still
    tot_distance = unname(tot_distance), # has its units still
    max_latitude = summarise_coords("Y", max),
    min_latitude = summarise_coords("Y", min),
    max_longitude = summarise_coords("X", max),
    min_longitude = summarise_coords("X", min),
    max_dist_centre = units::as_units(dists[i_max], dist_units),
    # unname() as a 1x1 matrix is subset to a vector named by its column
    lat_at_max_dist_centre = unname(coords[i_max, "Y"]),
    lon_at_max_dist_centre = unname(coords[i_max, "X"])
  )

  # check that sum_stats has the right number of rows (number of unique track
  # IDs) This is a sanity check, it should never happen.
  if (nrow(sum_stats) != length(unique(x[[move2::mt_track_id_column(x)]]))) {
    stop(
      "There is a problem with the summary statistics. ",
      "The number of rows in the summary statistics does not match ",
      "the number of unique track IDs in x."
    )
  }

  # rename track_id field to be the "track_id_column" in the original move2
  # object
  colnames(sum_stats)[which(
    colnames(sum_stats) == "track_id"
  )] <- move2::mt_track_id_column(x)

  return(sum_stats)
}
