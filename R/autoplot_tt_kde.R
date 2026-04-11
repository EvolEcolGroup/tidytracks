#' Autoplot a utilisation distribution created by kde
#' 
#' This autoplot function can be used to plot a specific kernel, rather
#' than the full tibble.
#' 
#' @param object an object of class \code{tt_kde}
#' @param ... not used
#' @importFrom ggplot2 autoplot
#' @returns a ggplot object
#' @export

autoplot.tt_kde <- function(object, ...) {

  # Create a terra SpatRaster from the list
  # assume x and y form a grid
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
