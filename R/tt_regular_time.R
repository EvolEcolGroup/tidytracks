#' Resample a `move2` track to regular time intervals by geometric interpolation
#'
#' Resamples one or more tracks stored in a `move2` object onto a regular time
#' grid.  A new grid point is placed every `interval` time units from the start
#' of the track. Tracks are processed independently, so different tracks may
#' have different temporal extents and the points from different tracks will not
#' have matching time stamps (as the starting points are different). Events
#' with an empty geometry (i.e. no location) are ignored.
#'
#' @section Spatial interpolation: Positions are linearly interpolated along the
#'   observed path, with a strategy dependent on the map projection (using a
#'   strategy similar to [move2::mt_interpolate()]):
#'
#' \itemize{
#'   \item \strong{No CRS} – positions are linearly interpolated along the
#'     Euclidean segments connecting consecutive observations.
#'   \item \strong{Geographic CRS (lon/lat)} – the path is treated as a
#'     spherical polyline and [s2::s2_interpolate_normalized()] is
#'     used, which follows great-circle arcs between consecutive points.
#'   \item \strong{Projected CRS} – the track is temporarily transformed to
#'     WGS 84 (EPSG:4326) for spherical interpolation via
#'     [s2::s2_interpolate_normalized()], then the resulting points
#'     are transformed back to the original CRS.
#' }
#'
#' @section Temporal-to-spatial mapping: Raw observations are often unevenly
#'   spaced in both time and space. \code{tt_regular_time} accounts for this by
#'   first computing the normalised arc-length fraction of every input point
#'   along the path that is interpolated (using [s2::s2_distance()] along the
#'   spherical path for geographic and projected CRS, and Euclidean distance
#'   when there is no CRS), then using [stats::approx()] to linearly
#'   interpolate those fractions at each new time step.  A stationary stretch
#'   of the track (many observations covering little distance) is therefore
#'   correctly treated as slow movement, not as a spatial shortcut.
#'
#' @section Attribute interpolation: Numeric event-level columns are linearly
#'   interpolated at the new time steps using [stats::approx()] (they are `NA`
#'   for tracks with fewer than two non-missing values). Non-numeric
#'   columns receive the value of the nearest preceding (or simultaneous)
#'   observation via \code{\link[base]{findInterval}}. Track-level attributes
#'   stored in \code{\link[move2]{mt_track_data}} are preserved unchanged.
#'
#' @param x A `move2` object. Timestamps (as returned by [event_time()]) must be
#'   [base::POSIXct].
#' @param interval Resampling interval as a [`units::units`] object
#'   carrying time units convertible to seconds (e.g. \code{as_units(60,
#'   "s")}, \code{as_units(1, "min")}, \code{as_units(0.5,
#'   "h")}).  Every track is resampled at this cadence between its own first and
#'   last observation.  Passing a plain numeric value raises an error to prevent
#'   silent unit mismatches.
#' @param max_time_lag Optional upper bound on interpolation gaps, supplied as a
#'   [`units::units`] object with time units convertible to seconds (same rules
#'   as \code{interval}).  Grid points that fall strictly inside a gap between
#'   consecutive input observations that is \emph{longer} than
#'   \code{max_time_lag} are silently dropped from the output.  Pass \code{NULL}
#'   (the default) to interpolate across all gaps regardless of size.
#' @param snap_times Logical (default \code{FALSE}).  When \code{TRUE}, each
#'   track's grid begins at the first whole-interval boundary that is strictly
#'   after the track's first observation, rather than at the first observation
#'   itself.  For example, with \code{interval = 10 min}, a track starting at
#'   08:04 will have its first resampled point at 08:10, then 08:20, 08:30, and
#'   so on.  This aligns grids across tracks that share the same epoch, so that
#'   overlapping tracks will have identical timestamps at each step.
#'
#' @return A `move2` object on a regular time grid.  The CRS, time-column name,
#'   track-id column name, geometry column name, and track-level attributes of
#'   \code{x} are all preserved.
#'
#' @seealso \code{\link[move2]{mt_interpolate}} for the move2 implementation of
#'   the same spatial strategy with flexible time targets (including
#'   interpolating to specific missing timestamps);
#'   [units::as_units()] for constructing the required \code{units}
#'   objects; [s2::s2_interpolate_normalized()] for spherical arc sampling.
#'
#' @examples
#' library(sf)
#'
#' # Build a simple three-point track with irregular time gaps
#' times <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(5, 90, 200)
#' geom <- st_sfc(
#'   st_point(c(-0.10, 51.50)),
#'   st_point(c(-0.05, 51.52)),
#'   st_point(c(0.00, 51.54)),
#'   crs = 4326
#' )
#' track <- move2::mt_as_move2(
#'   sf::st_sf(
#'     timestamp = times,
#'     speed_ms  = c(2.1, 3.4, 1.8),
#'     track_id  = "gull_01",
#'     geometry  = geom
#'   ),
#'   time_column = "timestamp",
#'   track_id_column = "track_id"
#' )
#'
#' # Resample to one fix per minute
#' resampled <- tt_regular_time(track, interval = as_units(1, "min"))
#' resampled
#'
#' # Resample to 30-second fixes, skipping gaps > 2 minutes
#' resampled_gapped <- tt_regular_time(
#'   track,
#'   interval     = as_units(30, "s"),
#'   max_time_lag = as_units(2, "min")
#' )
#' resampled_gapped
#'
#' # Resample to one fix per minute, snapping times to whole-minute boundaries
#' resampled_snap <- tt_regular_time(track,
#'   interval = as_units(1, "min"),
#'   snap_times = TRUE
#' )
#' resampled_snap
#'
#' @export
tt_regular_time <- function(
  x,
  interval,
  max_time_lag = NULL,
  snap_times = FALSE
) {
  # Validate inputs
  if (!move2::mt_is_move2(x)) {
    stop("`x` must be a move2 object.", call. = FALSE)
  }

  if (!inherits(move2::mt_time(x), "POSIXct")) {
    stop(
      "`tt_regular_time` requires POSIXct timestamps. ",
      paste0(
        "Convert the time column with `mt_set_time()` before calling ",
        "this function."
      ),
      call. = FALSE
    )
  }

  interval_sec <- .to_seconds(interval, "interval")
  max_lag_sec <- if (is.null(max_time_lag)) {
    Inf
  } else {
    .to_seconds(max_time_lag, "max_time_lag")
  }

  if (!isTRUE(snap_times) && !identical(snap_times, FALSE)) {
    stop("`snap_times` must be TRUE or FALSE.", call. = FALSE)
  }

  # Collect move2 metadata
  input_crs <- sf::st_crs(x)
  has_crs <- !is.na(input_crs)
  time_col <- move2::mt_time_column(x)
  track_col <- move2::mt_track_id_column(x)
  geom_col <- attr(x, "sf_column")
  track_ids <- unique(move2::mt_track_id(x))
  track_data <- move2::mt_track_data(x)

  # Resample each track independently
  results <- lapply(track_ids, function(tid) {
    track <- x[as.character(move2::mt_track_id(x)) == as.character(tid), ]
    .resample_one_track(
      track = track,
      interval_sec = interval_sec,
      max_lag_sec = max_lag_sec,
      snap_times = snap_times,
      has_crs = has_crs,
      input_crs = input_crs,
      time_col = time_col,
      track_col = track_col,
      geom_col = geom_col
    )
  })

  # Recombine and restore move2 structure
  valid_results <- Filter(Negate(is.null), results)
  if (length(valid_results) == 0L) {
    empty_track_data <- track_data[0, , drop = FALSE]
    return(move2::mt_set_track_data(x[0, , drop = FALSE], empty_track_data))
  }

  combined <- do.call(rbind, valid_results)
  out <- move2::mt_as_move2(
    combined,
    time_column = time_col,
    track_id_column = track_col
  )
  out_track_ids <- unique(as.character(combined[[track_col]]))
  out_track_data <- track_data[
    as.character(track_data[[track_col]]) %in% out_track_ids,
    ,
    drop = FALSE
  ]
  move2::mt_set_track_data(out, out_track_data)
}

################################################################################
# Internal functions
################################################################################

#' Validate a units object and convert it to a plain numeric in seconds
#'
#' @param x   The argument value to check.
#' @param arg The argument name (used in error messages).
#' @return A single positive finite \code{numeric} giving the duration in
#'   seconds.
#' @keywords internal
#' @noRd
.to_seconds <- function(x, arg) {
  if (!inherits(x, "units")) {
    stop(
      "`",
      arg,
      "` must be a units object ",
      "(e.g. `as_units(60, \"s\")` or `as_units(1, \"min\")`).",
      call. = FALSE
    )
  }

  if (length(x) != 1L) {
    stop("`", arg, "` must be a length-1 units object.", call. = FALSE)
  }

  out <- tryCatch(
    as.numeric(units::set_units(x, "s")),
    error = function(e) {
      stop(
        "`",
        arg,
        "` must carry time units convertible to seconds; ",
        "got '",
        units::deparse_unit(x),
        "'.",
        call. = FALSE
      )
    }
  )
  if (length(out) != 1L || !is.finite(out) || out <= 0) {
    stop("`", arg, "` must be a positive duration.", call. = FALSE)
  }
  out
}


#' Resample a single-track move2 slice onto a regular time grid
#'
#' @param track        A single-track move2/sf object (already subset).
#' @param interval_sec Resampling interval in seconds (plain numeric).
#' @param max_lag_sec  Maximum interpolation gap in seconds (plain numeric,
#'   may be \code{Inf}).
#' @param snap_times   Logical; if \code{TRUE} the grid starts at the first
#'   whole-interval boundary strictly after the track's first observation.
#' @param has_crs      Logical; does the object carry a CRS?
#' @param input_crs    CRS object from \code{sf::st_crs}.
#' @param time_col,track_col,geom_col Column name strings.
#' @return An \code{sf} data frame, or \code{NULL} when all grid points fall
#'   inside large gaps.
#' @keywords internal
#' @noRd
.resample_one_track <- function(
  track,
  interval_sec,
  max_lag_sec,
  snap_times = FALSE,
  has_crs,
  input_crs,
  time_col,
  track_col,
  geom_col
) {
  track_label <- as.character(move2::mt_track_id(track)[1L])
  # events without a location (empty geometry) are ignored
  track <- track[!sf::st_is_empty(track), ]
  track <- track[order(move2::mt_time(track)), ]

  if (nrow(track) < 2L) {
    stop(
      "Each track must have at least 2 observations with a location to ",
      "interpolate. Track '",
      track_label,
      "' has only ",
      nrow(track),
      " row(s) with a location.",
      call. = FALSE
    )
  }

  times <- move2::mt_time(track)
  t_sec <- as.numeric(times)
  # keep the time zone of the input (including "", the local time zone)
  tz <- attr(times, "tzone")

  t_start <- if (isTRUE(snap_times)) {
    # First whole-interval boundary strictly after the track's first timestamp.
    # ceiling division: floor(t / interval) * interval + interval
    floor(t_sec[1L] / interval_sec) * interval_sec + interval_sec
  } else {
    t_sec[1L]
  }

  if (t_start > t_sec[length(t_sec)]) {
    return(NULL)
  }

  t_new <- seq(t_start, t_sec[length(t_sec)], by = interval_sec)

  # Projected tracks are interpolated along the spherical path in WGS 84, so
  # the positions of the points along the path have to be measured on that
  # same path (fractions of the projected, Euclidean path differ from it)
  is_projected <- has_crs && !.is_geographic(input_crs)
  path <- if (is_projected) sf::st_transform(track, 4326L) else track
  path_crs <- if (is_projected) sf::st_crs(4326L) else input_crs

  seg_len <- .path_lengths(path, has_crs, path_crs)
  cum_len <- c(0, cumsum(seg_len))
  total_len <- cum_len[length(cum_len)]

  if (total_len == 0) {
    stop(
      "All locations in track '",
      unique(as.character(move2::mt_track_id(track))),
      "' are coincident; cannot interpolate a stationary track.",
      call. = FALSE
    )
  }

  space_frac <- cum_len / total_len

  s_norm <- stats::approx(
    x = t_sec,
    y = space_frac,
    xout = t_new,
    method = "linear",
    rule = 1L
  )$y

  if (is.finite(max_lag_sec)) {
    gap_sizes <- diff(t_sec)
    large_gaps <- which(gap_sizes > max_lag_sec)
    if (length(large_gaps) > 0L) {
      interval_idx <- findInterval(t_new, t_sec, rightmost.closed = TRUE)
      in_gap <- rep(FALSE, length(t_new))
      inside_segments <- interval_idx >= 1L & interval_idx < length(t_sec)
      idx <- which(inside_segments)
      if (length(idx) > 0L) {
        seg_idx <- interval_idx[idx]
        strictly_inside <- t_new[idx] > t_sec[seg_idx] &
          t_new[idx] < t_sec[seg_idx + 1L]
        in_gap[idx] <- strictly_inside & gap_sizes[seg_idx] > max_lag_sec
      }
      t_new <- t_new[!in_gap]
      s_norm <- s_norm[!in_gap]
    }
  }

  if (length(t_new) == 0L) {
    return(NULL)
  }

  # find the segment of the path of each new location once, as interpolating
  # along the whole path walks along it for each location (quadratic time)
  on_path <- .locate_on_path(s_norm * total_len, seg_len)
  new_geom <- if (!has_crs) {
    .interpolate_no_crs(track, on_path)
  } else if (!is_projected) {
    .interpolate_s2(track, on_path, input_crs)
  } else {
    pts_geo <- .interpolate_s2(path, on_path, path_crs)
    sf::st_transform(pts_geo, input_crs)
  }

  attr_cols <- setdiff(names(track), c(time_col, track_col, geom_col))
  new_times <- .POSIXct(t_new, tz = tz)
  n_new <- length(t_new)

  base_df <- data.frame(
    stats::setNames(list(new_times), time_col),
    # keep the type of the track ids (e.g. factor or integer), as in the
    # track data
    stats::setNames(
      list(rep(move2::mt_track_id(track)[1], n_new)),
      track_col
    ),
    stringsAsFactors = FALSE,
    # keep column names that are not syntactic (e.g. with spaces) unchanged
    check.names = FALSE
  )

  if (length(attr_cols) > 0L) {
    # approx() needs at least two values (e.g. a column can be all NA for a
    # track); with fewer, the interpolated values are NA
    interpolate_values <- function(vals) {
      if (sum(!is.na(vals)) < 2L) {
        return(rep(NA_real_, n_new))
      }
      stats::approx(
        x = t_sec,
        y = vals,
        xout = t_new,
        method = "linear",
        rule = 1L
      )$y
    }
    attr_df <- lapply(stats::setNames(attr_cols, attr_cols), function(col) {
      vals <- track[[col]]
      if (inherits(vals, "units")) {
        units::set_units(
          interpolate_values(as.numeric(vals)),
          units::deparse_unit(vals),
          mode = "standard"
        )
      } else if (is.numeric(vals)) {
        interpolate_values(vals)
      } else {
        # value of the last observation at or before each new time (a time
        # equal to the last observation takes the value of that observation)
        vals[findInterval(t_new, t_sec)]
      }
    })
    base_df <- cbind(
      base_df,
      as.data.frame(attr_df, stringsAsFactors = FALSE, check.names = FALSE)
    )
  }

  # keep the name of the geometry column of the input (added as a column and
  # selected by name, as it could be the name of an argument of st_sf(), e.g.
  # "crs")
  base_df[[geom_col]] <- new_geom
  sf::st_sf(base_df, sf_column_name = geom_col)
}


#' Compute segment lengths along a point track
#'
#' Uses \code{\link[s2]{s2_distance}} for geographic CRS and Euclidean
#' distance for projected or missing CRS.
#'
#' @param sf_obj  A sorted sf POINT object.
#' @param has_crs Logical; does the object carry a CRS?
#' @param crs     CRS object returned by \code{sf::st_crs}.
#' @return Numeric vector of length \code{nrow(sf_obj) - 1}.
#' @noRd
.path_lengths <- function(sf_obj, has_crs, crs) {
  if (has_crs && .is_geographic(crs)) {
    p1 <- s2::as_s2_geography(sf_obj[-nrow(sf_obj), ])
    p2 <- s2::as_s2_geography(sf_obj[-1L, ])
    as.numeric(s2::s2_distance(p1, p2))
  } else {
    xy <- sf::st_coordinates(sf_obj)
    sqrt(diff(xy[, "X"])^2 + diff(xy[, "Y"])^2)
  }
}


#' Locate distances along a path on the segments of the path
#'
#' @param dist    Numeric vector of distances along the path, between 0 and
#'   the length of the path.
#' @param seg_len Numeric vector of the lengths of the segments of the path
#'   (as returned by \code{.path_lengths}), with a positive sum.
#' @return A list with \code{index}, the segment in which each distance falls
#'   (segment \code{i} goes from point \code{i} to point \code{i + 1}), and
#'   \code{frac}, the fraction of that segment covered at that distance.
#' @noRd
.locate_on_path <- function(dist, seg_len) {
  cum_len <- c(0, cumsum(seg_len))
  # segments of length zero are skipped, as the last point at or before each
  # distance starts a segment of positive length; distances at the end of the
  # path fall at the end of its last segment of positive length
  index <- findInterval(dist, cum_len)
  last_seg <- max(which(seg_len > 0))
  at_end <- index > last_seg
  index[at_end] <- last_seg
  frac <- (dist - cum_len[index]) / seg_len[index]
  frac[at_end] <- 1
  list(index = index, frac = pmin(frac, 1))
}


#' Interpolate along the segments of a path in Euclidean space (no CRS)
#'
#' @param sf_obj  An sf POINT object with no CRS.
#' @param on_path A list with the segments and fractions of the segments of
#'   the points to interpolate, as returned by \code{.locate_on_path}.
#' @return An \code{sfc_POINT} with \code{length(on_path$index)} points and no
#'   CRS.
#' @noRd
.interpolate_no_crs <- function(sf_obj, on_path) {
  xy <- sf::st_coordinates(sf_obj)[, c("X", "Y"), drop = FALSE]
  from <- xy[on_path$index, , drop = FALSE]
  to <- xy[on_path$index + 1L, , drop = FALSE]
  new_xy <- from + on_path$frac * (to - from)
  sf::st_cast(sf::st_sfc(sf::st_multipoint(new_xy)), "POINT")
}


#' Interpolate along the segments of a path using
#' \code{s2::s2_interpolate_normalized}
#'
#' @param sf_obj  An sf POINT object with a geographic (lon/lat) CRS.
#' @param on_path A list with the segments and fractions of the segments of
#'   the points to interpolate, as returned by \code{.locate_on_path}.
#' @param crs     The CRS to attach to the output \code{sfc}.
#' @return An \code{sfc_POINT} with \code{length(on_path$index)} points.
#' @noRd
.interpolate_s2 <- function(sf_obj, on_path, crs) {
  xy <- sf::st_coordinates(sf_obj)
  # one line for each point to interpolate, along its segment of the path
  ends <- c(rbind(on_path$index, on_path$index + 1L))
  s2_lines <- s2::s2_make_line(
    longitude = xy[ends, "X"],
    latitude = xy[ends, "Y"],
    feature_id = rep(seq_along(on_path$index), each = 2L)
  )
  pts <- s2::s2_interpolate_normalized(s2_lines, on_path$frac)
  sf::st_as_sfc(pts, crs = crs)
}


#' Test whether a CRS is geographic (lon/lat)
#'
#' @param crs A CRS object returned by \code{sf::st_crs}.
#' @return \code{TRUE} if the CRS uses angular (geographic) coordinates.
#' @noRd
.is_geographic <- function(crs) {
  isTRUE(crs$IsGeographic) ||
    grepl("longlat|geographic", crs$proj4string %||% "", ignore.case = TRUE)
}


#' Null-coalescing operator
#' @noRd
`%||%` <- function(a, b) {
  if (is.null(a) || !nzchar(as.character(a)[1L])) b else a
}
