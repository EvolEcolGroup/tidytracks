#' Resample a `move2` track to regular time intervals by geometric interpolation
#'
#' Resamples one or more tracks stored in a `move2` object onto a regular time
#' grid.  A new grid point is placed every `interval` time units from the start
#' of the track. Tracks are processed independently, so different tracks may
#' have different temporal extents and the points from different tracks will not
#' have matching time stamps (as the starting points are different).
#'
#' @section Spatial interpolation: Positions are linearly interpolated along the
#'   observed path, with a strategy dependent on the map projection (using a
#'   strategy similar to [move2::mt_interpolate()]):
#'
#' \itemize{
#'   \item \strong{No CRS} – [sf::st_line_sample()] is called on the
#'     Euclidean linestring connecting the observations.
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
#'   along the path (using [s2::s2_distance()] for geographic CRS and Euclidean
#'   distance otherwise), then using [stats::approx()] to linearly interpolate
#'   those fractions at each new time step.  A stationary stretch of the track
#'   (many observations covering little distance) is therefore correctly treated
#'   as slow movement, not as a spatial shortcut.
#'
#' @section Attribute interpolation: Numeric event-level columns are linearly
#'   interpolated at the new time steps using [stats::approx()]. Non-numeric
#'   columns receive the value of the nearest preceding observation via
#'   \code{\link[base]{findInterval}}. Track-level attributes stored in
#'   \code{\link[move2]{mt_track_data}} are preserved unchanged.
#'
#' @param x A `move2` object.  Timestamps (as returned by [event_time()]) must be
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
#'   track-id column name, and track-level attributes of \code{x} are all
#'   preserved.
#'
#' @seealso \code{\link[move2]{mt_interpolate}} for the move2 implementation of
#'   the same spatial strategy with flexible time targets (including
#'   interpolating to specific missing timestamps);
#'   [units::as_units()] for constructing the required \code{units}
#'   objects; [sf::st_line_sample()] for Euclidean path sampling;
#'   [s2::s2_interpolate_normalized()] for spherical arc sampling.
#'
#' @examples
#' library(sf)
#' library(move2)
#' library(units)
#'
#' # Build a simple three-point track with irregular time gaps
#' times <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(5, 90, 200)
#' geom <- sf::st_sfc(
#'   sf::st_point(c(-0.10, 51.50)),
#'   sf::st_point(c(-0.05, 51.52)),
#'   sf::st_point(c(0.00, 51.54)),
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
#'
#' # Resample to one fix per minute, snapping times to whole-minute boundaries
#' resampled_snap <- tt_regular_time(track, interval = as_units(1, "min"),
#'                                   snap_times = TRUE)
#' resampled_snap
#'
#' @export
tt_regular_time <- function(x, interval, max_time_lag = NULL, snap_times = FALSE) {
  # Validate inputs
  if (!move2::mt_is_move2(x)) {
    stop("`x` must be a move2 object.", call. = FALSE)
  }

  if (!inherits(move2::mt_time(x), "POSIXct")) {
    stop("`tt_regular_time` requires POSIXct timestamps. ",
      "Convert the time column with `mt_set_time()` before calling this function.",
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
      track        = track,
      interval_sec = interval_sec,
      max_lag_sec  = max_lag_sec,
      snap_times   = snap_times,
      has_crs      = has_crs,
      input_crs    = input_crs,
      time_col     = time_col,
      track_col    = track_col,
      geom_col     = geom_col
    )
  })

  # Recombine and restore move2 structure
  valid_results <- Filter(Negate(is.null), results)
  if (length(valid_results) == 0L) {
    empty_track_data <- track_data[0, , drop = FALSE]
    return(move2::mt_set_track_data(x[0, , drop = FALSE], empty_track_data))
  }

  combined <- do.call(rbind, valid_results)
  out <- move2::mt_as_move2(combined,
    time_column     = time_col,
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
    stop("`", arg, "` must be a units object ",
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
      stop("`", arg, "` must carry time units convertible to seconds; ",
        "got '", units::deparse_unit(x), "'.",
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
.resample_one_track <- function(track, interval_sec, max_lag_sec,
                                snap_times = FALSE,
                                has_crs, input_crs,
                                time_col, track_col, geom_col) {
  track <- track[order(move2::mt_time(track)), ]

  if (nrow(track) < 2L) {
    stop("Each track must have at least 2 observations to interpolate. ",
      "Track '", unique(as.character(move2::mt_track_id(track))),
      "' has only ", nrow(track), " row(s).",
      call. = FALSE
    )
  }

  times <- move2::mt_time(track)
  t_sec <- as.numeric(times)
  tz <- attr(times, "tzone") %||% "UTC"

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

  seg_len <- .path_lengths(track, has_crs, input_crs)
  cum_len <- c(0, cumsum(seg_len))
  total_len <- cum_len[length(cum_len)]

  if (total_len == 0) {
    stop("All locations in track '",
      unique(as.character(move2::mt_track_id(track))),
      "' are coincident; cannot interpolate a stationary track.",
      call. = FALSE
    )
  }

  space_frac <- cum_len / total_len

  s_norm <- stats::approx(
    x      = t_sec,
    y      = space_frac,
    xout   = t_new,
    method = "linear",
    rule   = 1L
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
        strictly_inside <- t_new[idx] > t_sec[seg_idx] & t_new[idx] < t_sec[seg_idx + 1L]
        in_gap[idx] <- strictly_inside & gap_sizes[seg_idx] > max_lag_sec
      }
      t_new <- t_new[!in_gap]
      s_norm <- s_norm[!in_gap]
    }
  }

  if (length(t_new) == 0L) {
    return(NULL)
  }

  new_geom <- if (!has_crs) {
    .interpolate_no_crs(track, s_norm)
  } else if (.is_geographic(input_crs)) {
    .interpolate_s2(track, s_norm, input_crs)
  } else {
    track_geo <- sf::st_transform(track, 4326L)
    pts_geo <- .interpolate_s2(track_geo, s_norm, sf::st_crs(4326L))
    sf::st_transform(pts_geo, input_crs)
  }

  attr_cols <- setdiff(names(track), c(time_col, track_col, geom_col))
  new_times <- as.POSIXct(t_new, origin = "1970-01-01", tz = tz)
  n_new <- length(t_new)

  base_df <- data.frame(
    stats::setNames(list(new_times), time_col),
    stats::setNames(
      list(rep(unique(as.character(move2::mt_track_id(track))), n_new)),
      track_col
    ),
    stringsAsFactors = FALSE
  )

  if (length(attr_cols) > 0L) {
    attr_df <- lapply(stats::setNames(attr_cols, attr_cols), function(col) {
      vals <- track[[col]]
      if (inherits(vals, "units")) {
        interpolated <- stats::approx(
          x = t_sec,
          y = as.numeric(vals),
          xout = t_new,
          method = "linear",
          rule = 1L
        )$y
        units::set_units(
          interpolated,
          units::deparse_unit(vals),
          mode = "standard"
        )
      } else if (is.numeric(vals)) {
        stats::approx(
          x = t_sec,
          y = vals,
          xout = t_new,
          method = "linear",
          rule = 1L
        )$y
      } else {
        vals[findInterval(t_new, t_sec, all.inside = TRUE)]
      }
    })
    base_df <- cbind(
      base_df,
      as.data.frame(attr_df, stringsAsFactors = FALSE)
    )
  }

  sf::st_sf(base_df, geometry = new_geom)
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


#' Interpolate along a path using \code{sf::st_line_sample} (no CRS)
#'
#' @param sf_obj An sf POINT object with no CRS.
#' @param s_norm Numeric vector of normalised distances in \[0, 1\].
#' @return An \code{sfc_POINT} with \code{length(s_norm)} points and no CRS.
#' @noRd
.interpolate_no_crs <- function(sf_obj, s_norm) {
  coords <- sf::st_coordinates(sf_obj)
  line <- sf::st_sfc(sf::st_linestring(coords[, c("X", "Y")]))
  sampled <- sf::st_line_sample(line, sample = s_norm)
  sf::st_cast(sampled, "POINT")
}


#' Interpolate along a path using \code{s2::s2_interpolate_normalized}
#'
#' @param sf_obj An sf POINT object with a geographic (lon/lat) CRS.
#' @param s_norm Numeric vector of normalised arc-length fractions in \[0, 1\].
#' @param crs    The CRS to attach to the output \code{sfc}.
#' @return An \code{sfc_POINT} with \code{length(s_norm)} points.
#' @noRd
.interpolate_s2 <- function(sf_obj, s_norm, crs) {
  xy <- sf::st_coordinates(sf_obj)
  s2_line <- s2::s2_make_line(longitude = xy[, "X"], latitude = xy[, "Y"])
  pts <- s2::s2_interpolate_normalized(s2_line, s_norm)
  sf::st_as_sfc(pts, crs = crs)
}


#' Test whether a CRS is geographic (lon/lat)
#'
#' @param crs A CRS object returned by \code{sf::st_crs}.
#' @return \code{TRUE} if the CRS uses angular (geographic) coordinates.
#' @noRd
.is_geographic <- function(crs) {
  isTRUE(crs$IsGeographic) ||
    grepl("longlat|geographic",
      crs$proj4string %||% "",
      ignore.case = TRUE
    )
}


#' Null-coalescing operator
#' @noRd
`%||%` <- function(a, b) {
  if (is.null(a) || !nzchar(as.character(a)[1L])) b else a
}
