#' @keywords internal
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
      x1 = x1, y = y1, x2 = x2, y2 = y2,
      sequential = FALSE, paired = TRUE, measure = "geodesic"
    )
  } else {
    sqrt((x2 - x1)^2 + (y2 - y1)^2)
  }
}
