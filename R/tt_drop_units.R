#' A version of units::drop_units that is compatible with move2 and sf objects
#'
#' @description Many functions in `tidytrack` produced values with units
#' (implemented via the package `units`). Units are very useful in ensuring that
#' operations are performed in the correct units, but they are not always
#' compatible with other packages, such as `ggplot2`. This function drops the
#' units from the columns of a `move2` or `sf` object.
#'
#' @details Note that `geom_*` functions in `tidytrack` automatically drop
#' units, so there is no need to use this function before plotting if you use
#' the custom geometries in this package.
#'
#' @param x A move2 or sf object
#' @return A move2 or sf object with units dropped
#' @export

tt_drop_units <- function(x) {
  for (i in seq_along(names(x))) {
    if (inherits(x[[i]], "units")) {
      x[[i]] <- units::drop_units(x[[i]])
    }
  }
  return(x)
}
