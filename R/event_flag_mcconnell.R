#' Clean data based on speed
#'
#' This function uses the algorithm by McConnell et al. (2012) to clean data
#' based on speed. This is a port of the `speedfilter` function from the `trip`
#' package.
#'
#' @param x A move2 object
#' @param max_speed speed, provided as a `units` object (e.g.
#' `as_units(50, 'm/s')`.
#' @return A logical vector of the same length as the number of events in `x`,
#' indicating which points are valid.
#' @export


event_flag_mcconnell <- function(x, max_speed = NULL) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Determine if the coordinate system is in longitude/latitude
  projected <- !sf::st_is_longlat(x)

  # If no max_speed is provided, return the original object
  if (is.null(max_speed)) {
    stop("max_speed must be provided")
  } else if (!inherits(max_speed, "units")) {
    stop("max_speed must be a units object: e.g. units::as_units(50, 'm/s')")
  } else {
    # figure out appropriate units give the current projection
    ref_units <- units(sf::st_distance(x$geometry[1:2]) /
      units::as_units(60, "h")) # we measure time in hours
    # convert the speed into the reference units of the projection
    max_speed <- units::ud_convert(
      unclass(max_speed),
      units(max_speed),
      ref_units
    )
    # drop units for max_speed
    max_speed <- as.numeric(max_speed)
  }

  # Extract coordinates and timestamps
  coords <- sf::st_coordinates(x)
  time <- event_time(x)
  id <- factor(event_track_id(x)) # ensure this is a factor

  # Define parameters for filtering
  pprm <- 3 # Points per running mean (must be an odd number > 3)
  track_ids <- levels(id) # Unique track_ids

  # Create a logical vector to track valid points
  valid_all <- rep(TRUE, nrow(coords))

  # Loop through each unique track ID
  for (i_track in track_ids) {
    this_track <- id == i_track
    xy <- coords[this_track, ] # coordinates for this trip
    track_time <- time[this_track] # time for this trip
    npts <- nrow(xy)

    # # Ensure running mean parameters are valid
    # # this makes little sense as it is set to 3 in the beginning
    # if (pprm %% 2 == 0 || pprm < 3) {
    #   stop(
    #     "Points per running mean should be odd and greater than 3, pprm=3"
    #   )
    # }

    # Initialize speed values
    RMS <- rep(max_speed + 1, npts) # Root mean square speed
    offset <- pprm - 1
    valid_track <- rep(TRUE, npts)

    # Check if there are enough points for filtering
    if (npts < (pprm + 1)) {
      warning("Not enough points to filter ID: ", i_track, " continuing . . . ")
      valid_all[this_track] <- valid_track # just accept them all
      next # go to next track
    }

    index <- 1:npts

    # Iteratively filter points exceeding max_speed
    while (any(RMS > max_speed, na.rm = TRUE)) {
      n <- length(which(valid_track)) # points to use
      x1 <- xy[valid_track, ] # coordinates to use

      # TODO check what these speeds are
      # Calculate speed between consecutive points
      speed1 <- dist_fast(x1[-nrow(x1), 1], x1[-nrow(x1), 2],
        x1[-1, 1], x1[-1, 2],
        longlat = !projected
      ) /
        (diff(unclass(track_time[valid_track])) / 3600) # time in hours

      # Calculate running mean speed
      speed2 <- dist_fast(x1[-((nrow(x1) - 1):nrow(x1)), 1],
        x1[-((nrow(x1) - 1):nrow(x1)), 2],
        x1[-(1:2), 1], x1[-(1:2), 2],
        longlat = !projected
      ) /
        ((unclass(track_time[valid_track][-c(1, 2)]) -
          unclass(track_time[valid_track][-c(n - 1, n)])) /
          3600) # time in hours

      this_index <- index[valid_track] # indices for this iteration
      npts <- length(speed1) # number of points (number of segments, really)
      if (npts < pprm) {
        next
      }

      # Compute root means square
      # indices for speed 1 (i.e. one step at a time)
      sub1 <- rep(1:2, npts - offset) + rep(1:(npts - offset), each = 2)
      # indices for speed 2 (every other point, e.g. 1&3, 2&4, 3&5, etc.)
      sub2 <- rep(c(0, 2), npts - offset) +
        rep(1:(npts - offset), each = 2)
      # speeds in 4 columns (2 per type of speed) # TODO I don't fully understand this
      rmsRows <- cbind(
        matrix(speed1[sub1], ncol = offset, byrow = TRUE),
        matrix(speed2[sub2], ncol = offset, byrow = TRUE)
      )
      # root mean square of each row
      RMS <- c(
        rep(0, offset),
        sqrt(rowSums(rmsRows^2) / ncol(rmsRows))
      )

      # Identify and flag high-speed segments
      RMS[length(RMS)] <- 0 # set last value as zero (from NA)
      # set if RMS is greater than max speed allowed
      bad <- RMS > max_speed
      # find contiguous sections of high speed
      segs <- cumsum(c(0, abs(diff(bad))))
      # flag points with highest speed within each contiguous section
      rmsFlag <- unlist(lapply(split(RMS, segs), function(x) {
        ifelse((1:length(x)) == which.max(x), TRUE, FALSE)
      }), use.names = FALSE)
      rmsFlag[!bad] <- FALSE
      RMS[rmsFlag] <- -10

      # Mark invalid points
      valid_track[this_index][rmsFlag > 0] <- FALSE
    }

    # Update valid points
    valid_all[this_track] <- valid_track
  }

  valid_all
}
