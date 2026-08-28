#' A fast function to compute distances
#'
#' For unprojected longitudes and latitudes, the distance is computed as the
#' geodesic distance (via the `geodist` package); for projected coordinates, the
#' Euclidean distance is used.
#' @param x1 A vector of x coordinates
#' @param y1 A vector of y coordinates
#' @param x2 A vector of x coordinates
#' @param y2 A vector of y coordinates
#' @param longlat Logical, if TRUE, the coordinates are assumed to be in
#'   unprojected longitudes and latitudes. If FALSE, the coordinates are assumed
#'   to be in projected coordinates.
#' @return A vector of distances
#' @keywords internal
#' @noRd
dist_fast <- function(x1, y1, x2, y2, longlat = TRUE) {
  if (missing(y1)) {
    if (!is.matrix(x1)) {
      stop("x1 is not a matrix and multiple arguments not specified")
    }
    if (nrow(x1) < 2) stop("x1 has too few rows")
    if (ncol(x1) < 2) stop("x1 has too few columns")
    x2 <- x1[-1, 1]
    y1 <- x1[-nrow(x1), 2]
    y2 <- x1[-1, 2]
    x1 <- x1[-nrow(x1), 1]
  }
  nx <- length(x1)
  if (nx != length(y1) || nx != length(x2) || nx != length(y2)) {
    stop("arguments must have equal lengths")
  }
  if (longlat) {
    geodist::geodist_vec(
      x1 = x1,
      y = y1,
      x2 = x2,
      y2 = y2,
      sequential = FALSE,
      paired = TRUE,
      measure = "geodesic"
    )
  } else {
    sqrt((x2 - x1)^2 + (y2 - y1)^2)
  }
}
