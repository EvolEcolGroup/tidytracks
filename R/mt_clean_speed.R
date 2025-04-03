#' Clean data based on speed
#'
#' This function uses the algorithm by McConnell et al. (2012) to clean data
#' based on speed. This is a port of the `speedfilter` function from the `trip`.
#'
#' @param x A move2 object
#' @param max_speed speed, provided as a `units` object (e.g.
#' units::as_units(50, 'm/s').
#' @return A logical vector indicating which points are valid
#' @export


mt_clean_speed <- function (x, max_speed=NULL) {

  # Determine if the coordinate system is in longitude/latitude
  projected <- !sf::st_is_longlat(x)
  if (is.na(projected)) {
    projected <- FALSE
    # warning("coordinate system is NA, assuming longlat . . .")
  }

  # If no max_speed is provided, return the original object
  if (is.null(max_speed)) {
    print("no max_speed given, nothing to do here")
    return(x)
  } else if (!inherits(max_speed, "units")) {
    stop("max_speed must be a units object: e.g. units::as_units(50, 'm/s')")
  } else {
    # figure out appropriate units give the current projection
    ref_units <- units(sf::st_distance(x$geometry[1:2])/
                         units::as_units(60,"s")) # we measure time in seconds
    # convert the speed into the reference units of the projection
    max_speed <- units::ud_convert(max_speed,
                                   units(max_speed),
                                   ref_units)
    # drop units for max_speed
    max_speed <- as.numeric(max_speed)
  }

  # Extract coordinates and timestamps
  coords <- sf::st_coordinates(x)
  time <- move2::mt_time(x)
  id <- factor(move2::mt_track_id(x)) # ensure this is a factor

#  x <- coords[, 1]
#  y <- coords[, 2]

  # Define parameters for filtering
  pprm <- 3  # Points per running mean (must be an odd number > 3)
  grps <- levels(id)  # Unique trip IDs

  # Ensure coordinate lengths match
#  if (length(x) != length(y))
#    stop("x and y vectors must be of same length")
#  if (length(x) != length(time))
#    stop("Length of times not equal to number of points")

  # Create a logical vector to track valid points
  okFULL <- rep(TRUE, nrow(coords))

  # Loop through each unique trip ID
  for (sub in grps) {

    ind <- id == sub
    xy <- coords[ind, ] # coordinates for this trip
    tms <- time[ind] # time for this trip
    npts <- nrow(xy)

    # Ensure running mean parameters are valid
    # this makes little sense as it is set to 3 in the beginning
    if (pprm%%2 == 0 || pprm < 3) {
      msg <- paste("Points per running mean should be odd and",
                   "greater than 3, pprm=3")
      stop(msg)
    }

    # Initialize speed values
    RMS <- rep(max_speed + 1, npts) # Root mean square speed
    offset <- pprm - 1
    ok <- rep(TRUE, npts)

    # Check if there are enough points for filtering
    if (npts < (pprm + 1)) {
      warning("Not enough points to filter ID: ", sub, " continuing . . . ")
      okFULL[ind] <- ok # just accept them all
      next # go to next individual
    }

    index <- 1:npts

    # Iteratively filter points exceeding max_speed
    while (any(RMS > max_speed, na.rm=TRUE)) {
      n <- length(which(ok)) # points to use
      x1 <- xy[ok, ] # coordinates to use

      # TODO check what these speeds are
      # Calculate speed between consecutive points
      speed1 <- trip::trackDistance(x1[-nrow(x1), 1], x1[-nrow(x1), 2],
                              x1[-1, 1], x1[-1, 2],
                              longlat=!projected) /
        (diff(unclass(tms[ok])) / 3600)

      # Calculate running mean speed
      speed2 <- trip::trackDistance(x1[-((nrow(x1) - 1):nrow(x1)), 1],
                              x1[-((nrow(x1) - 1):nrow(x1)), 2],
                              x1[-(1:2), 1], x1[-(1:2), 2],
                              longlat=!projected) /
        ((unclass(tms[ok][-c(1, 2)]) -
            unclass(tms[ok][-c(n - 1, n)])) /
           3600)

      browser()
      thisIndex <- index[ok] # indices for this iteration
      npts <- length(speed1) # number of points (number of segments, really)
      if (npts < pprm)
        next

      # Compute root means square
      # indices for speed 1 (i.e. one step at a time)
      sub1 <- rep(1:2, npts - offset) + rep(1:(npts - offset), each=2)
      # indices for speed 2 (every other point, e.g. 1&3, 2&4, 3&5, etc.)
      sub2 <- rep(c(0, 2), npts - offset) +
        rep(1:(npts - offset), each=2)
      # speeds in 4 columns (2 per type of speed) # TODO I don't fully understand this
      rmsRows <- cbind(matrix(speed1[sub1], ncol=offset, byrow=TRUE),
                       matrix(speed2[sub2], ncol=offset, byrow=TRUE))
      # root mean square
      RMS <- c(rep(0, offset),
               sqrt(rowSums(rmsRows ^ 2) / ncol(rmsRows)))

      # Identify and flag high-speed segments
      RMS[length(RMS)] <- 0 # set last value as zero (from NA)
      # set if RMS is greater than max speed allowed
      bad <- RMS > max_speed
      # find contiguous sections of high speed
      segs <- cumsum(c(0, abs(diff(bad))))
      # flag points with highest speed within each contiguous section
      rmsFlag <- unlist(lapply(split(RMS, segs), function(x) {
        ifelse((1:length(x)) == which.max(x), TRUE, FALSE)
      }), use.names=FALSE)
      rmsFlag[!bad] <- FALSE
      RMS[rmsFlag] <- -10

      # Mark invalid points
      ok[thisIndex][rmsFlag > 0] <- FALSE
    }

    # Update valid points
    okFULL[ind] <- ok
  }

  okFULL
}

