#' Create isopleths from utilisation distributions
#' 
#' This method can be applied to a whole tibble of UDs, or to an individual
#' UD.
#' 
#' @param x either a tibble of class `hr_kde_tbl`, as created by [tt_hr_kde()],
#' or a `hr_kde` object from the `kde` column of a `hr_kde_tbl` tibble.
#' @param levels numeric vector of isopleth levels to create. Default is
#' `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels should be between
#' 0 and 1.
#' @return If `x` is a tibble, a tibble of class `hr_iso_tbl` with columns
#' `id`, `level`, and `geometry`. If `x` is a `hr_kde` object, 
#' a `sfc_GEOMETRYCOLLECTION` object.
#' @export

hr_iso <- function(x, levels = c(0.50, 0.95)) {
  UseMethod("hr_iso")
}

#' @export
#' @rdname hr_iso
hr_iso.hr_kde_tbl <- function(x, levels = c(0.50, 0.95)) {
  levels <- sort(levels)
  # apply hr_iso to each row of the tibble, and unnest the results
  iso_list <- x %>%
    dplyr::reframe(iso = purrr::map(.data$kde, ~ hr_iso(.x, levels))) %>%
    dplyr::pull(dplyr::any_of("iso")) %>%
    unlist(recursive = FALSE) %>%
    sf::st_sfc(crs = x$kde[[1]]$crs)
  # double each line of the tibble for each level
  res_tbl <- x %>%
    dplyr::select(-dplyr::any_of("kde")) %>%
    tidyr::uncount(length(levels)) %>%
    dplyr::mutate(level = rep(levels, times = nrow(x))) %>%
    dplyr::mutate(area = sf::st_area(iso_list)) %>%
    dplyr::mutate(geometry = iso_list) %>%
    sf::st_as_sf()
  class(res_tbl) <- c("hr_iso_tbl", class(res_tbl))
  return(res_tbl)
}

#' @export
#' @rdname hr_iso
hr_iso.hr_kde <- function(x, levels) {
  # check that levels are between 0 and 1
  if (any(levels < 0 | levels > 1)) {
    stop("levels should be between 0 and 1")
  }
  # compute the cumulative utilisation distribution
  kde_cud <- hr_kde_cud(x$z)
  
  # create a list of sf polygons for each level
  kde_polys <- lapply(levels, function(level) {
    # get the contour lines for this level
    contour_lines <- grDevices::contourLines(x$x, x$y, kde_cud,
                                             level = level
    )
    # convert to sf polygons
    sf_polys <- lapply(contour_lines, function(line) {
      sf::st_polygon(list(cbind(line$x, line$y)))
    })
    # combine into a single sf multipolygon
    sf::st_combine(sf::st_sfc(sf_polys, crs = x$crs))
  })
  # create a geometry set with one feature per level
  kde_polys <- sf::st_sfc(do.call(rbind, kde_polys), crs = x$crs)
  
  return(kde_polys)
}