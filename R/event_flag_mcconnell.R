#' Clean data based on speed
#'
#' This function uses the algorithm by McConnell et al. (1992) to clean data
#' based on speed. This is a port of the `speedfilter` function from the `trip`
#' package, with an optional endpoint check.
#'
#' When `check_first_last = TRUE`, the function also evaluates the first and
#' last currently valid point of each track using an endpoint Root Mean Square
#' (RMS):
#' - first point: RMS of speed(1,2) and speed(1,3)
#' - last point:  RMS of speed(n-1,n) and speed(n-2,n)
#'
#' If an endpoint is removed, the McConnell filter is rerun on the reduced
#' track, and the endpoint check is repeated until the result is stable.
#'
#' Speeds are computed between consecutive events of each track in time order,
#' whatever the order in which the events are stored in `x`. Events with an
#' empty geometry (i.e. no location) are ignored by the filter
#' and returned as valid. Consecutive events at the same location are treated
#' as having zero speed, even when they share the same timestamp (e.g.
#' duplicated records).
#'
#' @param x A move2 object.
#' @param max_speed Speed, provided as a `units` object, e.g.
#'   `as_units(50, "m/s")`.
#' @param check_first_last Logical. If `TRUE`, also evaluate the first and last
#'   currently valid point of each track using the endpoint RMS described above.
#'   If either endpoint is removed, the McConnell filter is rerun on the reduced
#'   track until the result is stable. It defaults to `FALSE` to maintain the
#'   original behaviour of the McConnell algorithm.
#' @return A logical vector of the same length as the number of events in `x`,
#'   indicating which points are valid.
#' @export
#' @examples
#' event_flag_mcconnell(example_tt, max_speed = as_units(50, "m/s"))
event_flag_mcconnell <- function(
  x,
  max_speed = NULL,
  check_first_last = FALSE
) {
  # ---------------------------------------------------------------------------
  # Input checks
  # ---------------------------------------------------------------------------
  # Ensure the supplied object is a move2 object. The algorithm assumes
  # access to move2 methods such as event_time() and event_track_id().
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Maximum speed threshold is mandatory because all filtering decisions
  # are based on comparing estimated speeds against this limit.
  if (is.null(max_speed)) {
    stop("max_speed must be provided")
  }

  # Require a units object to avoid ambiguity regarding speed units.
  # This prevents accidental mixing of km/h, m/s, etc.
  if (!inherits(max_speed, "units")) {
    stop("max_speed must be a units object: e.g. as_units(50, 'm/s')")
  }

  # Distances (and thus speeds) require a coordinate reference system.
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }

  # Determine whether coordinates are projected or longitude/latitude.
  # This controls how distances are calculated later.
  projected <- !sf::st_is_longlat(x)

  # If there are fewer than 2 events, no speed can be computed; nothing to
  # filter.
  if (nrow(x) < 2) {
    return(rep(TRUE, nrow(x)))
  }

  # Create a reference unit matching the coordinate system currently
  # used by the track. Distances are divided by 60 hours simply to
  # produce a speed unit compatible with the track CRS.
  ref_units <- units(
    sf::st_distance(sf::st_geometry(x)[1:2]) /
      units::as_units(60, "h")
  )

  # Convert user-supplied maximum speed into the same units that will
  # be generated internally by the distance calculations.
  max_speed <- units::ud_convert(
    unclass(max_speed),
    units(max_speed),
    ref_units
  )

  # Strip the units object and retain only the numeric value because
  # all subsequent calculations are performed numerically.
  max_speed <- as.numeric(max_speed)

  # Extract coordinates as a matrix.
  coords <- sf::st_coordinates(x)

  # Extract timestamps for all events, in seconds (move2 also allows dates and
  # units objects as timestamps).
  time <- event_time(x)
  if (inherits(time, "Date")) {
    time <- as.POSIXct(time)
  } else if (inherits(time, "units")) {
    time <- units::set_units(time, "s")
  }
  time <- as.numeric(time)

  # Extract track IDs and convert to a factor so that each track
  # can be processed independently.
  id <- factor(event_track_id(x))

  # ---------------------------------------------------------------------------
  # Order the located events by track and time
  # ---------------------------------------------------------------------------
  # Events with an empty geometry have no location; they are left out of the
  # filter (and returned as valid). Speeds are computed between consecutive
  # events of each track in time order, whatever the order in which the events
  # are stored in x (order() keeps events with the same time in the order in
  # which they are stored). All the tracks are then filtered together.
  located <- which(!is.na(coords[, 1]) & !is.na(coords[, 2]))
  track <- as.integer(id)
  rows <- located[order(track[located], time[located])]
  track <- track[rows]

  # As in the original implementation, tracks with fewer than four located
  # events (including tracks without any) are not filtered, with a warning
  # (unless check_first_last = TRUE, whose endpoint check can still flag their
  # first and last events).
  if (!isTRUE(check_first_last)) {
    too_short <- tabulate(track, nbins = nlevels(id)) < 4
    for (i_track in levels(id)[too_short]) {
      warning("Not enough points to filter ID: ", i_track, " continuing . . . ")
    }
  }

  filter <- if (isTRUE(check_first_last)) {
    mcconnell_check_first_last
  } else {
    mcconnell_filter
  }
  valid_all <- rep(TRUE, nrow(coords))
  valid_all[rows] <- filter(
    xy = coords[rows, , drop = FALSE],
    time = time[rows],
    track = track,
    max_speed = max_speed,
    projected = projected
  )
  valid_all
}

#' Speeds between pairs of locations for the McConnell filter
#'
#' Speeds are in distance units (of `dist`) per hour, as in the original
#' implementation. A step with no displacement has zero speed even if no time
#' elapsed (e.g. duplicated records), rather than NaN, which would stop bad
#' windows being detected.
#'
#' @param dist Distances between the locations `from` and `to`.
#' @param from,to Indices of the locations.
#' @param time Times of all the locations, in seconds.
#' @returns The speeds.
#' @keywords internal
#' @noRd
mcconnell_speed <- function(dist, from, to, time) {
  speed <- dist / ((time[to] - time[from]) / 3600)
  speed[!is.na(dist) & dist == 0] <- 0
  speed
}

#' An upper bound of geodesic distances on the WGS84 ellipsoid
#'
#' The great circle distance (with the haversine formula) on a sphere whose
#' radius is the polar radius of curvature of the ellipsoid, `a^2 / b`, is at
#' least the geodesic distance between the same longitudes and latitudes on
#' the ellipsoid: both radii of curvature of the ellipsoid (in the meridian
#' and in the prime vertical) are at most `a^2 / b` (which they reach at the
#' poles), so any path is no longer on the ellipsoid than on the sphere. The
#' bound is at most about 1% above the geodesic distance (at the equator), and
#' closest to it near the poles. A margin of a micrometre covers rounding
#' errors (e.g. in the cosine of latitudes close to the poles), which are much
#' smaller.
#'
#' @param xy Matrix of longitudes and latitudes.
#' @param from,to Indices of the locations.
#' @returns The upper bounds, in metres.
#' @keywords internal
#' @noRd
mcconnell_dist_bound <- function(xy, from, to) {
  a <- 6378137
  b <- a * (1 - 1 / 298.257223563)
  rad <- pi / 180
  lat_from <- xy[from, 2] * rad
  lat_to <- xy[to, 2] * rad
  h <- sin((lat_to - lat_from) / 2)^2 +
    cos(lat_from) * cos(lat_to) * sin((xy[to, 1] - xy[from, 1]) * rad / 2)^2
  2 * a^2 / b * asin(pmin(1, sqrt(h))) * (1 + 1e-9) + 1e-6
}

#' The McConnell speed filter, on all the tracks at once
#'
#' The algorithm of McConnell et al. (1992), as implemented in
#' `trip::speedfilter()`: in each pass, the root mean square (RMS) of the
#' speeds of a window of five consecutive valid locations is computed for the
#' location at its centre, from the speeds of the two steps before and after
#' it and of the steps from two locations before and to two locations after
#' it. In each run of consecutive locations whose RMS exceeds `max_speed`, the
#' one with the largest RMS (the first one, if several share it) is removed.
#' The passes go on, for each track, while a pass leaves a location above
#' `max_speed` that was not removed.
#'
#' The flags are the same as those of the original implementation, which
#' filtered each track on its own and computed all the speeds again in each
#' pass. Here, all the tracks are filtered together, and a pass only computes
#' the windows that include a location removed in the previous pass (the
#' others are unchanged). For longitudes and latitudes, geodesic distances are
#' only computed for the windows that could exceed `max_speed`: those whose RMS
#' is above it with an upper bound of the distances (see
#' `mcconnell_dist_bound()`), which is much faster to compute.
#'
#' @param xy Matrix of the coordinates of the locations, ordered by track and
#'   by time within each track.
#' @param time Times of the locations, in seconds.
#' @param track Track of each location (the locations of a track must be
#'   consecutive).
#' @param max_speed Maximum speed, in units of distance (of the coordinates)
#'   per hour.
#' @param projected Whether the coordinates are projected (otherwise they are
#'   longitudes and latitudes).
#' @returns A logical vector, `TRUE` for the valid locations.
#' @keywords internal
#' @noRd
mcconnell_filter <- function(xy, time, track, max_speed, projected) {
  n <- length(track)
  valid <- rep(TRUE, n)
  if (n == 0) {
    return(valid)
  }

  # ---------------------------------------------------------------------------
  # Links between valid locations
  # ---------------------------------------------------------------------------
  # The filter works on the sequence of the valid locations of each track.
  # Rather than subsetting the locations in each pass, each location keeps the
  # index of the previous (prv) and next (nxt) valid location in its track (NA
  # at the ends of the track), and these links are updated when locations are
  # removed (a doubly linked list).
  first <- c(TRUE, track[-1] != track[-n])
  last <- c(track[-1] != track[-n], TRUE)
  prv <- seq_len(n) - 1L
  prv[first] <- NA
  nxt <- seq_len(n) + 1L
  nxt[last] <- NA

  # ---------------------------------------------------------------------------
  # RMS speed of a window
  # ---------------------------------------------------------------------------
  # The window of a location c is made of the two valid locations before it
  # and the two after it in its track:
  #
  #   p2 -- p1 -- c -- n1 -- n2
  #
  # Its RMS is the root mean square of four speeds: of the steps p1 -> c and
  # c -> n1, and of the steps p2 -> c and c -> n2 (between locations two
  # apart, which help to identify isolated spikes). rms_of() computes it from
  # the distances of these four steps. The columns are in the order of the
  # original implementation, so that rowSums() gives identical values.
  rms_of <- function(centre, p2, p1, n1, n2, d_p1, d_n1, d_p2, d_n2) {
    speeds <- cbind(
      mcconnell_speed(d_p1, p1, centre, time),
      mcconnell_speed(d_n1, centre, n1, time),
      mcconnell_speed(d_p2, p2, centre, time),
      mcconnell_speed(d_n2, centre, n2, time)
    )
    sqrt(rowSums(speeds^2) / 4)
  }

  # The same, with the distances of the four steps computed by `dist`.
  rms_with <- function(dist, centre, p2, p1, n1, n2) {
    if (length(centre) == 0) {
      return(numeric(0))
    }
    rms_of(
      centre, p2, p1, n1, n2,
      dist(p1, centre), dist(centre, n1), dist(p2, centre), dist(centre, n2)
    )
  }

  # Exact distances: geodesic for longitudes and latitudes, and Euclidean for
  # projected coordinates.
  exact <- function(from, to) {
    dist_fast(
      xy[from, 1],
      xy[from, 2],
      xy[to, 1],
      xy[to, 2],
      longlat = !projected
    )
  }

  # Upper bounds of the geodesic distances, much faster to compute (see
  # mcconnell_dist_bound()).
  bound <- function(from, to) {
    mcconnell_dist_bound(xy, from, to)
  }

  # RMS of the windows of the locations `centre`. As in the original
  # implementation, a location without two valid locations on each side in its
  # track (one of the first two or last two of the track) has no window, and
  # gets 0. With longitudes and latitudes, the RMS is first computed with the
  # upper bounds of the distances: a window that is not above max_speed with
  # the bounds is not above it with the exact distances either, and also gets
  # 0 (its exact value is never used), so geodesic distances are only computed
  # for the few windows that could exceed max_speed.
  window_rms <- function(centre, first_pass = FALSE) {
    # The neighbours of each location in its window.
    p1 <- prv[centre]
    p2 <- prv[p1]
    n1 <- nxt[centre]
    n2 <- nxt[n1]
    rms <- rep(0, length(centre))

    # The locations with a complete window (p2 is NA when p1 is, and n2 when
    # n1 is).
    full <- which(!is.na(p2) & !is.na(n2))
    if (length(full) == 0) {
      return(rms)
    }

    if (!projected) {
      upper <- if (first_pass) {
        # In the first pass, the neighbours of each location are the adjacent
        # rows, so the bounds of the steps between consecutive locations, and
        # between locations two apart, are each computed only once (rather
        # than once for each of the two windows that share them).
        steps1 <- bound(seq_len(n - 1), seq_len(n - 1) + 1L)
        steps2 <- bound(seq_len(n - 2), seq_len(n - 2) + 2L)
        cf <- centre[full]
        rms_of(
          cf, p2[full], p1[full], n1[full], n2[full],
          steps1[cf - 1], steps1[cf], steps2[cf - 2], steps2[cf]
        )
      } else {
        rms_with(bound, centre[full], p2[full], p1[full], n1[full], n2[full])
      }
      # Only the windows that could exceed max_speed need their exact RMS.
      full <- full[which(upper > max_speed)]
    }

    rms[full] <- rms_with(
      exact, centre[full], p2[full], p1[full], n1[full], n2[full]
    )
    rms
  }

  # ---------------------------------------------------------------------------
  # Passes of the filter
  # ---------------------------------------------------------------------------
  # The first pass computes the windows of all the locations. A window is bad
  # when its RMS exceeds max_speed; `bad` holds the locations of the bad
  # windows, in the order of the locations (i.e. by track and time).
  rms <- window_rms(seq_len(n), first_pass = TRUE)
  bad <- which(rms > max_speed)

  while (length(bad) > 0) {
    # Group the bad windows into runs of consecutive valid locations: a new
    # run starts when the next valid location after a bad window is not the
    # next bad window. A run never spans two tracks, as the first two
    # locations of a track have no window.
    m <- length(bad)
    run <- cumsum(c(TRUE, nxt[bad[-m]] != bad[-1]))

    # In each run, the location with the largest RMS is removed (the first
    # one, if several share it, as order() keeps ties in their order).
    by_rms <- order(run, -rms[bad])
    flagged <- bad[by_rms[!duplicated(run[by_rms])]]

    # The original implementation filters a track again only if this pass
    # left a bad window that was not removed, i.e. if one of its runs had
    # more than one bad window. The other tracks are finished, even if
    # removing a location makes a new window bad.
    again <- unique(track[bad[tabulate(run)[run] > 1]])

    # Remove the flagged locations, and link the locations before and after
    # each of them. Removed locations are never next to each other (runs are
    # separated by at least one location that is not bad), so all the links
    # can be updated at once.
    valid[flagged] <- FALSE
    before <- prv[flagged]
    after <- nxt[flagged]
    nxt[before] <- after
    prv[after] <- before

    # The only windows that change are those that included a removed
    # location, i.e. the windows of the two valid locations on each side of
    # it; the others keep their RMS. Only the windows of the tracks that are
    # filtered again are needed.
    go_on <- track[flagged] %in% again
    before <- before[go_on]
    after <- after[go_on]
    changed <- unique(c(prv[before], before, after, nxt[after]))
    changed <- changed[!is.na(changed)]
    rms[changed] <- window_rms(changed)

    # The bad windows of the next pass: the bad windows that did not change
    # (in the tracks filtered again), and the changed windows that are bad.
    bad <- bad[!bad %in% c(flagged, changed) & track[bad] %in% again]
    bad <- sort(c(bad, changed[rms[changed] > max_speed]))
  }
  valid
}

#' The McConnell speed filter with a check of the first and last locations
#'
#' The first (or last) valid location of a track is removed if the RMS of the
#' speeds from it to the next two valid locations (or from the previous two)
#' exceeds `max_speed`, and the McConnell filter is then run again on the
#' remaining locations of the track, until the valid locations do not change.
#' All the tracks are filtered together, as in `mcconnell_filter()`, each until
#' its own locations do not change.
#'
#' @inheritParams mcconnell_filter
#' @returns A logical vector, `TRUE` for the valid locations.
#' @keywords internal
#' @noRd
mcconnell_check_first_last <- function(xy, time, track, max_speed, projected) {
  valid <- rep(TRUE, length(track))

  # Speeds between pairs of locations, with exact distances.
  speed <- function(from, to) {
    if (length(from) == 0) {
      return(numeric(0))
    }
    dist <- dist_fast(
      xy[from, 1],
      xy[from, 2],
      xy[to, 1],
      xy[to, 2],
      longlat = !projected
    )
    mcconnell_speed(dist, from, to, time)
  }

  # The tracks that are still being filtered. The original implementation
  # filtered each track on its own, until its valid locations did not change;
  # here, all these tracks go through each step together.
  active <- unique(track)
  while (length(active) > 0) {
    previous <- valid
    in_active <- track %in% active

    # -------------------------------------------------------------------------
    # Endpoint check
    # -------------------------------------------------------------------------
    # The positions, among the valid locations `v` of the active tracks, of
    # the first (starts) and last (ends) valid location of each track with at
    # least three of them (from the runs of their track ids).
    v <- which(valid & in_active)
    runs <- rle(track[v])
    ends <- cumsum(runs$lengths)
    ends <- ends[runs$lengths >= 3]
    starts <- ends - runs$lengths[runs$lengths >= 3] + 1
    first <- v[starts]
    last <- v[ends]

    # RMS of the speeds from the first location to the next two, and from the
    # previous two to the last location. Both endpoints are checked before
    # either is removed, as in the original implementation.
    rms_first <- sqrt(
      (speed(first, v[starts + 1])^2 + speed(first, v[starts + 2])^2) / 2
    )
    rms_last <- sqrt(
      (speed(v[ends - 1], last)^2 + speed(v[ends - 2], last)^2) / 2
    )
    valid[first[!is.na(rms_first) & rms_first > max_speed]] <- FALSE
    valid[last[!is.na(rms_last) & rms_last > max_speed]] <- FALSE

    # -------------------------------------------------------------------------
    # McConnell filter on the remaining locations
    # -------------------------------------------------------------------------
    # As in the original implementation, the filter starts again from all the
    # remaining locations of each track (not from its previous result).
    keep <- which(valid & in_active)
    filtered <- mcconnell_filter(
      xy = xy[keep, , drop = FALSE],
      time = time[keep],
      track = track[keep],
      max_speed = max_speed,
      projected = projected
    )
    valid[in_active] <- FALSE
    valid[keep[filtered]] <- TRUE

    # A track is finished when its valid locations did not change in this
    # step, or when none is left.
    active <- intersect(unique(track[valid != previous]), track[keep])
  }
  valid
}
