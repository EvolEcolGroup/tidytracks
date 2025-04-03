fast_distance <- function (x1, y1, x2, y2){
    if (longlat) {
      geodist::geodist(cbind(lon = c(x1, tail(x2, 1)), lat = c(y1, tail(y2, 1))),
                       sequential = TRUE, paired = FALSE, measure = "geodesic")/1000
    } else sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
  }


