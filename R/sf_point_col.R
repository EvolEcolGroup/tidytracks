#' Create a simple feature POINT geometry column
#' 
#' This function creates a simple feature POINT geometry column from
#' x and y columns in a data frame. The resulting object is
#' a `sf` geometry set that can be used as an additional spatial column
#' in an sf data frame, in addition to the primary geometry column.
#'
#' @param x A vector of x coordinates (e.g., longitude or easting)
#' @param y A vector of y coordinates (e.g., latitude or northing)
#' @param crs An optional coordinate reference system (CRS) to assign to
#' the geometry. This can be an EPSG code (numeric) or a proj4 string (character).
#' If NULL (default), no CRS is assigned.
#' @return A `sf` geometry set of POINT geometries
#' @export
#' @examples
#' sf_point_col(show_meta(shags_tt)$lon_colony,
#'   show_meta(shags_tt)$lat_colony,
#'   crs = 4326)
#' 
sf_point_col <- function(x, y, crs = NULL) {
  sf::st_sfc(
    mapply(
      function(x, y) sf::st_point(c(x, y)),
      x, y,
      SIMPLIFY = FALSE
    ),
    crs = crs
  )
}