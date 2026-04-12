#' Autoplot a utilisation distribution created by kde
#'
#' This autoplot function can be used to plot a specific kernel, rather than the
#' full tibble.
#'
#' @param object an object of class \code{tt_kde}
#' @param standardise logical, whether to standardise the density values to sum
#'   to 1. Default is TRUE.
#' @param ... not used
#' @importFrom ggplot2 autoplot
#' @returns a ggplot object
#' @export

autoplot.hr_kde <- function(object, standardise = TRUE, ...) {

  # check the ellipses are empty
  if (length(list(...)) > 0) {
    stop("additional arguments .. are not used")
  }
  
  if (standardise) {
    # standardise the density values to sum to 1
    object$z <- object$z / sum(object$z, na.rm = TRUE)
  }
  
  # Create a terra SpatRaster from the list object,
  # which includes x, y, z and crs
  r <- kde2spatraster(object)

  # Create the ggplot object using tidyterra
  p <- ggplot2::ggplot() +
    tidyterra::geom_spatraster(data = r) +
    ggplot2::labs(x = "longitude",
                  y = "latitude") +
    ggplot2::theme_minimal()
  
  return(p)
}

kde2spatraster <- function(kde) {
  # Create a terra SpatRaster from the list
  # assume x and y form a grid
  r <- terra::rast(t(kde$z)[nrow(kde$z):1,],
    crs = kde$crs$wkt,
    extent =terra::ext(min(kde$x), max(kde$x), min(kde$y), max(kde$y))
  )
  
  return(r)
}
