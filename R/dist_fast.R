#' A fast function to compute distances
#'
#' Computes the distance between each pair of locations (`x1[i]`, `y1[i]`)
#' and (`x2[i]`, `y2[i]`).
#'
#' @details For unprojected longitudes and latitudes, the distance is the
#' geodesic distance on the WGS84 ellipsoid (Karney 2013), computed by the
#' `geodist` package; for projected coordinates, it is the Euclidean distance,
#' in the units of the projection.
#'
#' @param x1,y1 Vectors of the x and y coordinates of the first location of
#'   each pair.
#' @param x2,y2 Vectors of the x and y coordinates of the second location of
#'   each pair, of the same length as `x1` and `y1`.
#' @param longlat Logical, if TRUE, the coordinates are assumed to be in
#'   unprojected longitudes and latitudes. If FALSE, the coordinates are assumed
#'   to be in projected coordinates.
#' @return A vector of distances (in metres for longitudes and latitudes), one
#'   per pair of locations.
#' @references Karney, C. F. F. (2013). Algorithms for geodesics. *Journal of
#'   Geodesy*, 87, 43-55. \doi{10.1007/s00190-012-0578-z}
#' @keywords internal
#' @noRd
dist_fast <- function(x1, y1, x2, y2, longlat = TRUE) {
  # each pair of locations takes one value from each of the four vectors, so
  # they must all be equally long (otherwise R would silently recycle the
  # shorter ones)
  n_coords <- lengths(list(x1, y1, x2, y2))
  if (any(n_coords != n_coords[1])) {
    stop("x1, y1, x2 and y2 must have the same length")
  }
  if (longlat) {
    # geodesic distances in metres, one per pair (paired = TRUE), rather than
    # the matrix of the distances between all locations
    geodist::geodist_vec(
      x1 = x1,
      y1 = y1,
      x2 = x2,
      y2 = y2,
      paired = TRUE,
      measure = "geodesic"
    )
  } else {
    # Euclidean distances, in the units of the projection
    sqrt((x2 - x1)^2 + (y2 - y1)^2)
  }
}
