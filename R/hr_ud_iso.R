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
    as.list()
  iso_list <- do.call(rbind, iso_list)
  # double each line of the tibble for each level
  res_tbl <- x %>%
    dplyr::select(-dplyr::any_of("ud")) %>%
    tidyr::uncount(length(levels)) %>%
    dplyr::bind_cols(iso_list) %>%
    sf::st_as_sf()
  # TODO verify if this class is sticky (I think we need to create methods to
  # avoid it being dropped by the sf methods)
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

  # contours for the cumulative utilisation distribution
  contours <- terra::as.contour(hr_cud(x), levels = levels)
  # cast to an sf object, and union the contours for each level to create
  # polygons
  contours <- sf::st_as_sf(contours)
  # avoid warnings during casting
  suppressWarnings(
    contours <- lapply(
      split(contours, contours$level),
      function(cont_lines) {
        cont_lines %>%
          sf::st_cast("LINESTRING") %>%
          # cast to polygon to create a close contour
          sf::st_cast("POLYGON") %>%
          # union the polygons for this level to create a single polygon (or
          # multipolygon)
          sf::st_union() %>%
          # even if we have a single polygon, recast to multipolygon to ensure
          # we have a consistent geometry type
          sf::st_cast("MULTIPOLYGON")
      }
    )
  )
  # recast list back to a single geometry set
  contours <- do.call(c, contours)
  # rename the geometry column, add the level column, and calculate area
  contours <- sf::st_as_sf(contours) %>% 
    dplyr::rename(geometry = x) %>%
    dplyr::mutate(level = levels, area = sf::st_area(.data$geometry),
                  .before = "geometry")
   return(contours)
  
}
