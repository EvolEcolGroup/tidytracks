x <- trip::walrus818[1:160, ]
max.speed <- 1000
test <- FALSE

speedfilter <- function(x, max.speed = NULL, test = FALSE) {
  # Ensure the input is a "trip" object
  if (!is(x, "trip")) {
    stop("only trip objects supported")
  }

  # Check if coordinates are projected
  projected <- trip:::sp_is_projected(x)
  if (is.na(projected)) {
    projected <- FALSE
    warning("coordinate system is NA, assuming longlat . . .")
  }

  # If no max.speed is provided, return the original object
  if (is.null(max.speed)) {
    print("no max.speed given, nothing to do here")
    return(x)
  }

  # Determine if the coordinate system is in longitude/latitude
  longlat <- !projected

  # Extract coordinates and timestamps
  coords <- coordinates(x)
  tids <- getTimeID(x) # dataframe with two columns (time, id)
  time <- tids[, 1]
  id <- factor(tids[, 2])
  x <- coords[, 1]
  y <- coords[, 2]

  # Define parameters for filtering
  pprm <- 3 # Points per running mean (must be an odd number > 3)
  grps <- levels(id) # Unique trip IDs

  # Ensure coordinate lengths match
  if (length(x) != length(y)) {
    stop("x and y vectors must be of same length")
  }
  if (length(x) != length(time)) {
    stop("Length of times not equal to number of points")
  }

  # Create a logical vector to track valid points
  okFULL <- rep(TRUE, nrow(coords))

  # Initialize test mode results
  if (test) {
    res <- list(speed = numeric(0), rms = numeric(0))
  }

  # Loop through each unique trip ID
  for (sub in grps) {
    # DEBUG
    sub <- grps[1]

    ind <- id == sub
    xy <- matrix(c(x[ind], y[ind]), ncol = 2) # coordinates for this trip
    tms <- time[ind] # time for this trip
    npts <- nrow(xy)

    # Ensure running mean parameters are valid
    # this makes little sense as it is set to 3 in the beginning
    if (pprm %% 2 == 0 || pprm < 3) {
      msg <- paste(
        "Points per running mean should be odd and",
        "greater than 3, pprm=3"
      )
      stop(msg)
    }

    # Initialize speed values
    RMS <- rep(max.speed + 1, npts) # Root mean square speed
    offset <- pprm - 1
    ok <- rep(TRUE, npts)

    # Check if there are enough points for filtering
    if (npts < (pprm + 1) && !test) {
      warning("Not enough points to filter ID: ", sub, " continuing . . . ")
      okFULL[ind] <- ok # just accept them all
      next # go to next individual
    }

    index <- 1:npts
    iter <- 1 # unnecessary, unless we using test mode, but we might use it later to get out if too many iterations

    # Iteratively filter points exceeding max.speed
    while (any(RMS > max.speed, na.rm = TRUE)) {
      n <- length(which(ok)) # points to use
      x1 <- xy[ok, ] # coordinates to use

      # TODO check what these speeds are
      # Calculate speed between consecutive points
      speed1 <- trackDistance(
        x1[-nrow(x1), 1],
        x1[-nrow(x1), 2],
        x1[-1, 1],
        x1[-1, 2],
        longlat = !projected
      ) /
        (diff(unclass(tms[ok])) / 3600)

      # Calculate running mean speed
      speed2 <- trackDistance(
        x1[-((nrow(x1) - 1):nrow(x1)), 1],
        x1[-((nrow(x1) - 1):nrow(x1)), 2],
        x1[-(1:2), 1],
        x1[-(1:2), 2],
        longlat = !projected
      ) /
        ((unclass(tms[ok][-c(1, 2)]) -
          unclass(tms[ok][-c(n - 1, n)])) /
          3600)

      thisIndex <- index[ok] # indices for this iteration
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
      # root mean square
      RMS <- c(
        rep(0, offset),
        sqrt(rowSums(rmsRows^2) / ncol(rmsRows))
      )

      # Store speed results if in test mode
      if (test & iter == 1) {
        res$speed <- c(res$speed, 0, speed1)
        res$rms <- c(res$rms, 0, RMS)
        break
      }

      # Identify and flag high-speed segments
      RMS[length(RMS)] <- 0 # set last value as zero (from NA)
      # set if RMS is greater than max speed allowed
      bad <- RMS > max.speed
      # find contiguous sections of high speed
      segs <- cumsum(c(0, abs(diff(bad))))
      # flag points with highest speed within each contiguous section
      rmsFlag <- unlist(
        lapply(split(RMS, segs), function(x) {
          ifelse((1:length(x)) == which.max(x), TRUE, FALSE)
        }),
        use.names = FALSE
      )
      rmsFlag[!bad] <- FALSE
      RMS[rmsFlag] <- -10

      # Mark invalid points
      ok[thisIndex][rmsFlag > 0] <- FALSE
    }

    # Update valid points
    okFULL[ind] <- ok
  }

  # Return test results or filtered points
  if (test) {
    return(res)
  }
  okFULL
}


################################################################################
# Loop through each unique trip ID
track_flag_mcconnell <- function(this_track, max_speed) {
  # ind <- id == sub
  # xy <- matrix(c(x[ind], y[ind]), ncol=2) # coordinates for this trip
  # tms <- time[ind] # time for this trip
  # npts <- nrow(xy)
  #
  # # Ensure running mean parameters are valid
  # # this makes little sense as it is set to 3 in the beginning
  # if (pprm%%2 == 0 || pprm < 3) {
  #   msg <- paste("Points per running mean should be odd and",
  #                "greater than 3, pprm=3")
  #   stop(msg)
  # }

  # Initialize speed values
  root_mean_sq <- rep(max_speed + 1, nrow(this_track)) # Set all root mean square slots to values that are too large
  offset <- pprm - 1
  points_ok <- rep(TRUE, nrow(this_track))

  # Check if there are enough points for filtering
  if (nrow(this_track) < (pprm + 1)) {
    warning("Not enough points to filter ID: ", sub, " continuing . . . ")
    okFULL[ind] <- points_ok # just accept them all
    next # go to next individual
  }

  index <- 1:nrow(this_track)

  # Iteratively filter points exceeding max.speed
  while (any(root_mean_sq > max_speed, na.rm = TRUE)) {
    n <- length(which(points_ok)) # points to use
    x1 <- st_geometry(this_track)[points_ok] # coordinates to use

    # TODO check what these speeds are
    empty <- st_as_sfc("POINT(EMPTY)", crs = st_crs(this_track))
    d <- st_distance(
      c(x1, empty), # head and tail seem to be quite slow on geometry objects (numeric indexing is not better)
      c(empty, x1),
      by_element = TRUE
    )
    # remove first and last element (which are Na)
    d <- d[-c(1L, length(d))]

    speed_1 <- d /
      units::as_units(diff(mt_time(this_track)[points_ok]))

    d2 <- st_distance(
      c(x1, empty, empty), # head and tail seem to be quite slow on geometry objects (numeric indexing is not better)
      c(empty, empty, x1),
      by_element = TRUE
    )
    # remove first two and last two elements
    d2 <- d2[-c(1L, 2L, length(d2) - 1, length(d2))]
    speed_2 <- d2 /
      units::as_units(diff(mt_time(this_track)[points_ok], lag = 2))

    #
    # # Calculate speed between consecutive points
    # speed1 <- trackDistance(x1[-nrow(x1), 1], x1[-nrow(x1), 2],
    #                         x1[-1, 1], x1[-1, 2],
    #                         longlat=!projected) /
    #   (diff(unclass(tms[ok])) / 3600)
    #
    # # Calculate running mean speed
    # speed2 <- trackDistance(x1[-((nrow(x1) - 1):nrow(x1))], # remove the last two elements
    #                         x1[-((nrow(x1) - 1):nrow(x1)), 2],
    #                         x1[-(1:2), 1], x1[-(1:2), 2], # remove the first two elements
    #                         longlat=!projected) /
    #   ((unclass(tms[ok][-c(1, 2)]) -
    #       unclass(tms[ok][-c(n - 1, n)])) /
    #      3600)

    thisIndex <- index[points_ok] # indices for this iteration
    npts <- length(speed_1) # number of points (number of segments, really)
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
    # root mean square
    root_mean_sq <- c(
      rep(0, offset),
      sqrt(rowSums(rmsRows^2) / ncol(rmsRows))
    )

    # Identify and flag high-speed segments
    root_mean_sq[length(root_mean_sq)] <- 0 # set last value as zero (from NA)
    # set if RMS is greater than max speed allowed
    bad <- root_mean_sq > max_speed
    # find contiguous sections of high speed
    segs <- cumsum(c(0, abs(diff(bad))))
    # flag points with highest speed within each contiguous section
    rmsFlag <- unlist(
      lapply(split(root_mean_sq, segs), function(x) {
        ifelse((1:length(x)) == which.max(x), TRUE, FALSE)
      }),
      use.names = FALSE
    )
    rmsFlag[!bad] <- FALSE
    root_mean_sq[rmsFlag] <- -10

    # Mark invalid points
    points_ok[thisIndex][rmsFlag > 0] <- FALSE
  }
  points_ok
}
