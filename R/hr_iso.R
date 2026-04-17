#' Create isopleths from utilisation distributions
#' 
#' This method can be applied to a whole tibble of UDs, or to an individual
#' UD.
#' 
#' @param x either a tibble of class `hr_ud_tbl`, as created by [tt_hr_kde()],
#' or a `SpatRaster` object from the `ud` column of a `hr_ud_tbl` tibble.
#' @param levels numeric vector of isopleth levels to create. Default is
#' `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels should be between
#' 0 and 1.
#' @return If `x` is a tibble, a tibble of class `hr_ud_iso_tbl` with columns
#' `id`, `level`, and `geometry`. If `x` is a `hr_ud` object, 
#' a `sfc_GEOMETRYCOLLECTION` object.
#' @export

hr_ud_iso <- function(x, levels = c(0.50, 0.95)) {
  UseMethod("hr_ud_iso")
}

#' @export
#' @rdname hr_ud_iso
hr_ud_iso.hr_ud_tbl <- function(x, levels = c(0.50, 0.95)) {
  levels <- sort(levels)
  # apply hr_ud_iso to each row of the tibble, and unnest the results
  iso_list <- x %>%
    dplyr::reframe(iso = purrr::map(.data$ud, ~ hr_ud_iso(.x, levels))) %>%
    dplyr::pull(dplyr::any_of("iso")) %>%
    unlist(recursive = FALSE) %>%
    sf::st_sfc(crs = x$ud[[1]]$crs)
  # double each line of the tibble for each level
  res_tbl <- x %>%
    dplyr::select(-dplyr::any_of("ud")) %>%
    tidyr::uncount(length(levels)) %>%
    dplyr::mutate(level = rep(levels, times = nrow(x))) %>%
    dplyr::mutate(area = sf::st_area(iso_list)) %>%
    dplyr::mutate(geometry = iso_list) %>%
    sf::st_as_sf()
  class(res_tbl) <- c("hr_poly_tbl", class(res_tbl))
  return(res_tbl)
}

#' @export
#' @rdname hr_ud_iso
hr_ud_iso.SpatRaster <- function(x, levels = c(0.50, 0.95)) {
  # check that levels are between 0 and 1
  if (any(levels < 0 | levels > 1)) {
    stop("levels should be between 0 and 1")
  }
  levels = sort(levels)
  # compute the cumulative utilisation distribution
  ud_cud <- hr_cud(x)
  
  # create a list of sf polygons for each level
  ud_polys <- lapply(levels, function(level) {
    # get the contour lines for this level
    contour_lines <- grDevices::contourLines(
      x = ud_cud$x,
      y = ud_cud$y,
      z = ud_cud$z,
      level = level
    )
    # convert to sf polygons
    sf_polys <- lapply(contour_lines, function(line) {
      sf::st_polygon(list(cbind(line$x, line$y)))
    })
    # combine into a single sf multipolygon
    sf::st_combine(sf::st_sfc(sf_polys, crs = terra::crs(x)))
  })
  # create a geometry set with one feature per level
  ud_polys <- sf::st_sfc(do.call(rbind, ud_polys), crs = terra::crs(x))
  return(ud_polys)
}
