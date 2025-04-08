#' Clean a `move2` object using McConnell's algorithm
#'
#' This function cleans a `move2` object using McConnell's algorithm. It removes
#' outliers based on the distance between consecutive points and the time
#' interval between them (more explanation; give reference TODO). This function
#' returns a clean `move2` object; to generate a column that flags events to
#' remove but does not remove them, use `event_flag_mcconnell()`.
#'
#' @param x A move2 object
#' @param max_speed speed, provided as a `units` object (e.g.
#' units::as_units(50, 'm/s').
#' @return A clean `move2` object with events removed
#' @export

mt_clean_mcconnell <- function (x, max_speed = NULL) {
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  # Check if max_speed is provided
  if (is.null(max_speed)) {
    print("no max_speed given, nothing to do here")
    return(x)
  } else if (!inherits(max_speed, "units")) {
    stop("max_speed must be a units object: e.g. units::as_units(50, 'm/s')")
  }

  # Call the event_flag_mcconnell function to get the valid points
  valid_points <- event_flag_mcconnell(x, max_speed)

  # Filter the move2 object based on the valid points
  x_clean <- x[valid_points, ]

  return(x_clean)
}
