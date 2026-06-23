#' Clean data based on speed
#'
#' This function uses the algorithm by McConnell et al. (2012) to clean data
#' based on speed. This is a port of the `speedfilter` function from the `trip`
#' package, with an optional endpoint check.
#'
#' When `check_first_last = TRUE`, the function also evaluates the first and
#' last currently valid point of each track using an endpoint RMS:
#' - first point: RMS of speed(1,2) and speed(1,3)
#' - last point:  RMS of speed(n-1,n) and speed(n-2,n)
#'
#' If an endpoint is removed, the McConnell filter is rerun on the reduced
#' track, and the endpoint check is repeated until the result is stable.
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

event_flag_mcconnell <- function(x, max_speed = NULL, check_first_last = FALSE) {
  
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
  
  # Determine whether coordinates are projected or longitude/latitude.
  # This controls how distances are calculated later.
  projected <- !sf::st_is_longlat(x)
  
  # If there are fewer than 2 events, no speed can be computed; nothing to filter.
  if (nrow(x) < 2) {
    return(rep(TRUE, nrow(x)))
  }

  # Create a reference unit matching the coordinate system currently
  # used by the track. Distances are divided by 60 hours simply to
  # produce a speed unit compatible with the track CRS.
  ref_units <- units(sf::st_distance(x$geometry[1:2]) /
                       units::as_units(60, "h"))
  
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
  
  # Extract timestamps for all events.
  time <- event_time(x)
  
  # Extract track IDs and convert to a factor so that each track
  # can be processed independently.
  id <- factor(event_track_id(x))
  
  # ---------------------------------------------------------------------------
  # Filtering parameters
  # ---------------------------------------------------------------------------
  # pprm originates from the original McConnell implementation and
  # determines the number of points involved in each moving RMS calculation.
  pprm <- 3
  
  # List of unique track IDs.
  track_ids <- levels(id)
  
  # ---------------------------------------------------------------------------
  # Helper: speed between two points i and j
  # ---------------------------------------------------------------------------
  # Computes speed using:
  #   speed = distance / elapsed_time
  #
  # Elapsed time is expressed in hours, ensuring consistency with the
  # original McConnell implementation.
  speed_between <- function(xy, tt, i, j, projected) {
    dist_fast(
      xy[i, 1], xy[i, 2],
      xy[j, 1], xy[j, 2],
      longlat = !projected
    ) / ((unclass(tt[j]) - unclass(tt[i])) / 3600)
  }
  
  # ---------------------------------------------------------------------------
  # Helper: original McConnell core algorithm
  # ---------------------------------------------------------------------------
  # This function reproduces the original McConnell speed filter logic
  # for a single track.
  #
  # The algorithm repeatedly identifies suspicious sections based on
  # RMS speed values and removes the most extreme point within each
  # contiguous region exceeding the speed threshold.
  #
  # Logic is intentionally maintained exactly as in the original
  # implementation.
  # ---------------------------------------------------------------------------
  mcconnell_core_track <- function(xy, track_time, max_speed, projected,
                                   pprm = 3, warn_short = TRUE,
                                   track_label = NULL) {
    
    # Number of points in this track.
    npts <- nrow(xy)
    
    # Track validity vector; starts with all points considered valid.
    valid_track <- rep(TRUE, npts)
    
    # Initialise RMS values larger than max_speed so the loop runs at least once.
    RMS <- rep(max_speed + 1, npts)
    
    # Offset used in the original algorithm.
    offset <- pprm - 1
    
    # Original point indices.
    index <- seq_len(npts)
    
    # McConnell requires at least pprm + 1 points.
    if (npts < (pprm + 1)) {
      
      if (warn_short) {
        
        if (is.null(track_label)) {
          
          warning("Not enough points to filter this track, continuing . . . ")
          
        } else {
          
          warning(
            "Not enough points to filter ID: ",
            track_label,
            " continuing . . . "
          )
          
        }
      }
      
      # If too short, return all points as valid.
      return(valid_track)
    }

    # Continue until all RMS values are below the threshold.
    while (any(RMS > max_speed, na.rm = TRUE)) {
      
      # Number of currently valid points.
      n <- length(which(valid_track))
      
      # Subset coordinates to valid points only.
      x1 <- xy[valid_track, , drop = FALSE]
      
      # ---------------------------------------------------------------------
      # Consecutive-point speed estimates
      # ---------------------------------------------------------------------
      # Speed between:
      #   point 1 -> point 2
      #   point 2 -> point 3
      #   ...
      speed1 <- dist_fast(
        x1[-nrow(x1), 1], x1[-nrow(x1), 2],
        x1[-1, 1], x1[-1, 2],
        longlat = !projected
      ) / (diff(unclass(track_time[valid_track])) / 3600)
      
      # ---------------------------------------------------------------------
      # Skip-one speed estimates
      # ---------------------------------------------------------------------
      # Speed between:
      #   point 1 -> point 3
      #   point 2 -> point 4
      #   ...
      #
      # These help identify isolated spikes.
      speed2 <- dist_fast(
        x1[-((nrow(x1) - 1):nrow(x1)), 1],
        x1[-((nrow(x1) - 1):nrow(x1)), 2],
        x1[-(1:2), 1],
        x1[-(1:2), 2],
        longlat = !projected
      ) / (
        (unclass(track_time[valid_track][-c(1, 2)]) -
           unclass(track_time[valid_track][-c(n - 1, n)])) / 3600
      )
      
      # Indices corresponding to currently retained points.
      this_index <- index[valid_track]
      
      # Number of adjacent segments.
      nseg <- length(speed1)
      
      # Too few segments to compute RMS windows.
      if (nseg < pprm) {
        next
      }
      
      # ---------------------------------------------------------------------
      # Window construction
      # ---------------------------------------------------------------------
      # Create rolling windows of adjacent-segment speeds.
      sub1 <- rep(1:2, nseg - offset) +
        rep(1:(nseg - offset), each = 2)
      
      # Create rolling windows of skip-one speeds.
      sub2 <- rep(c(0, 2), nseg - offset) +
        rep(1:(nseg - offset), each = 2)
      
      # Combine consecutive and skip-one speeds into RMS windows.
      rmsRows <- cbind(
        matrix(speed1[sub1], ncol = offset, byrow = TRUE),
        matrix(speed2[sub2], ncol = offset, byrow = TRUE)
      )
      
      # Calculate RMS value for each window.
      RMS <- c(
        rep(0, offset),
        sqrt(rowSums(rmsRows^2) / ncol(rmsRows))
      )
      
      # Original implementation forces final position to zero.
      RMS[length(RMS)] <- 0
      
      # Identify windows exceeding maximum speed.
      bad <- RMS > max_speed
      
      # Group contiguous bad windows.
      segs <- cumsum(c(0, abs(diff(bad))))
      
      # ---------------------------------------------------------------------
      # Candidate point selection
      # ---------------------------------------------------------------------
      # Within each contiguous bad region, select only the point with
      # the highest RMS value.
      rmsFlag <- unlist(
        lapply(split(RMS, segs), function(z) {
          ifelse(seq_along(z) == which.max(z), TRUE, FALSE)
        }),
        use.names = FALSE
      )
      
      # Ignore regions below threshold.
      rmsFlag[!bad] <- FALSE
      
      # Mark candidate RMS values.
      RMS[rmsFlag] <- -10
      
      # Remove selected points from the valid set.
      valid_track[this_index][rmsFlag > 0] <- FALSE
    }
    
    valid_track
  }
  
  # ---------------------------------------------------------------------------
  # Helper: endpoint RMS filter
  # ---------------------------------------------------------------------------
  # Evaluates current first and last valid points.
  #
  # First point:
  #   RMS(speed(1,2), speed(1,3))
  #
  # Last point:
  #   RMS(speed(n-1,n), speed(n-2,n))
  #
  # If either RMS exceeds max_speed, the endpoint is flagged.
  # ---------------------------------------------------------------------------
  endpoint_rms_flags <- function(xy, track_time, valid_track,
                                 max_speed, projected) {
    
    flags <- rep(FALSE, length(valid_track))
    
    # Indices of currently valid points.
    idx <- which(valid_track)
    
    # Need at least three valid points to evaluate endpoints.
    if (length(idx) < 3) {
      return(flags)
    }
    
    # -----------------------------------------------------------------------
    # First endpoint
    # -----------------------------------------------------------------------
    s12 <- speed_between(xy, track_time, idx[1], idx[2], projected)
    s13 <- speed_between(xy, track_time, idx[1], idx[3], projected)
    
    rms_first <- sqrt((s12^2 + s13^2) / 2)

    if (is.finite(rms_first) && rms_first > max_speed) {
      flags[idx[1]] <- TRUE
    }
    
    # -----------------------------------------------------------------------
    # Last endpoint
    # -----------------------------------------------------------------------
    k <- length(idx)
    
    s_n1n <- speed_between(
      xy, track_time,
      idx[k - 1], idx[k],
      projected
    )
    
    s_n2n <- speed_between(
      xy, track_time,
      idx[k - 2], idx[k],
      projected
    )
    
    rms_last <- sqrt((s_n1n^2 + s_n2n^2) / 2)
    
    if (is.finite(rms_last) && rms_last > max_speed) {
      flags[idx[k]] <- TRUE
    }
    
    flags
  }
  
  # ---------------------------------------------------------------------------
  # Helper: combined filtering procedure for one track
  # ---------------------------------------------------------------------------
  #
  # When check_first_last = FALSE:
  #   Run standard McConnell filter only.
  #
  # When check_first_last = TRUE:
  #   1. Check endpoints.
  #   2. Remove flagged endpoints.
  #   3. Rerun McConnell filter.
  #   4. Repeat until no changes occur.
  # ---------------------------------------------------------------------------
  filter_one_track <- function(xy, track_time, max_speed, projected,
                               check_first_last, pprm, track_label = NULL) {
    
    # Preserve original behaviour exactly.
    if (!isTRUE(check_first_last)) {
      
      return(
        mcconnell_core_track(
          xy = xy,
          track_time = track_time,
          max_speed = max_speed,
          projected = projected,
          pprm = pprm,
          warn_short = TRUE,
          track_label = track_label
        )
      )
    }
    
    # Start with all points valid.
    valid_track <- rep(TRUE, nrow(xy))
    
    repeat {
      
      # Store previous state for convergence testing.
      prev_valid <- valid_track
      
      # Step 1: evaluate endpoints.
      end_flags <- endpoint_rms_flags(
        xy = xy,
        track_time = track_time,
        valid_track = valid_track,
        max_speed = max_speed,
        projected = projected
      )
      
      # Remove flagged endpoints.
      if (any(end_flags)) {
        valid_track[end_flags] <- FALSE
      }
      
      # Remaining points.
      keep <- which(valid_track)
      
      # If nothing remains, stop.
      if (length(keep) == 0) {
        break
      }
      
      # Step 2: run McConnell filter on reduced track.
      reduced_valid <- mcconnell_core_track(
        xy = xy[keep, , drop = FALSE],
        track_time = track_time[keep],
        max_speed = max_speed,
        projected = projected,
        pprm = pprm,
        warn_short = FALSE,
        track_label = track_label
      )
      
      # Rebuild validity vector in original coordinates.
      new_valid <- rep(FALSE, length(valid_track))
      new_valid[keep[reduced_valid]] <- TRUE
      
      valid_track <- new_valid
      
      # Step 3: stop when no further changes occur.
      if (identical(valid_track, prev_valid)) {
        break
      }
    }
    
    valid_track
  }
  
  # ---------------------------------------------------------------------------
  # Apply filtering track-by-track
  # ---------------------------------------------------------------------------
  # The McConnell algorithm operates independently on each track.
  # Results are assembled back into a validity vector matching the
  # original event order.
  # ---------------------------------------------------------------------------
  valid_all <- rep(TRUE, nrow(coords))
  
  for (i_track in track_ids) {
    
    # Select events belonging to the track.
    this_track <- id == i_track
    
    # Track coordinates.
    xy <- coords[this_track, , drop = FALSE]
    
    # Track timestamps.
    track_time <- time[this_track]
    
    # Run filtering procedure.
    valid_all[this_track] <- filter_one_track(
      xy = xy,
      track_time = track_time,
      max_speed = max_speed,
      projected = projected,
      check_first_last = check_first_last,
      pprm = pprm,
      track_label = i_track
    )
  }
  
  # Return final validity vector matching input event order.
  valid_all
}
