#' Create isopleths from utilisation distributions
#'
#' This method can be applied to a whole tibble of UDs, or to an individual UD.
#'
#' @param x either a tibble of class `hr_ud_tbl`, as created by [hr_kde()], or a
#'   `SpatRaster` object from the `ud` column of a `hr_ud_tbl` tibble.
#' @param levels numeric vector of isopleth levels to create. Default is
#'   `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels should be
#'   between 0 and 1.
#' @return If `x` is a tibble, a tibble of class `hr_poly_tbl` with columns
#'   `id`, `level`, and `geometry`. If `x` is a `hr_ud` object, a
#'   `sfc_GEOMETRYCOLLECTION` object.
#' @export
#' @family home_range
#' @examples
#' example_kde <- hr_kde(example_tt)
#' example_iso <- hr_ud_iso(example_kde)
#' example_iso
#'
#' # now plot the isopleths
#' library(ggplot2)
#' ggplot(example_iso) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
hr_ud_iso <- function(x, levels = c(0.50, 0.95)) {
  UseMethod("hr_ud_iso")
}

#' @export
#' @rdname hr_ud_iso
# Note that we have a generic method for a tibble as the hr_ud_tbl class is lost
# on group_map operations
hr_ud_iso.tbl_df <- function(x, levels = c(0.50, 0.95)) {
  stopifnot_hr_ud_table(x)
  # Work with a plain list locally while preserving a loaded object's packing.
  x <- unwrap_ud_column(x)

  levels <- sort(levels)

  res_tbl <- x %>%
    dplyr::mutate(iso = purrr::map(.data$ud, hr_ud_iso, levels = levels)) %>%
    dplyr::select(-dplyr::any_of("ud")) %>%
    tidyr::unnest(dplyr::any_of("iso"))

  res_tbl <- sf::st_as_sf(res_tbl)
  class(res_tbl) <- c("hr_poly_tbl", class(res_tbl))
  res_tbl
}


#' @export
#' @rdname hr_ud_iso
hr_ud_iso.SpatRaster <- function(x, levels = c(0.50, 0.95)) {
  if (any(levels < 0 | levels > 1)) {
    stop("levels should be between 0 and 1")
  }
  levels <- sort(levels)

  # check that x has a ud layer
  if (!("ud" %in% names(x))) {
    stop("x must have a layer named 'ud'")
  }

  empty_iso <- function(x) {
    sf::st_sf(
      level = numeric(0),
      area = numeric(0),
      geometry = sf::st_sfc(crs = sf::st_crs(terra::crs(x)))
    )
  }

  # 1) Try to create contours
  contours <- tryCatch(
    terra::as.contour(hr_cud(x), levels = levels),
    error = function(e) {
      warning("No isopleths could be computed: ", conditionMessage(e))
      return(empty_iso(x))
    }
  )

  # If tryCatch returned already-empty sf, stop here
  if (inherits(contours, "sf")) {
    return(contours)
  }

  # 2) If no geometries, return empty
  if (is.null(contours) || nrow(contours) == 0) {
    warning("No isopleths could be computed")
    return(empty_iso(x))
  }

  # 3) Convert to sf
  contours_sf <- tryCatch(
    sf::st_as_sf(contours),
    error = function(e) {
      warning("Contours could not be converted to sf: ", conditionMessage(e))
      return(empty_iso(x))
    }
  )

  if (nrow(contours_sf) == 0) {
    return(empty_iso(x))
  }

  # Make sure level exists
  if (!"level" %in% names(contours_sf)) {
    warning("Contour object has no `level` column")
    return(empty_iso(x))
  }

  # 4) Split by level and build polygons
  split_contours <- split(contours_sf, contours_sf$level)

  poly_list <- purrr::imap(
    split_contours,
    function(cont_lines, lvl) {
      tryCatch(
        {
          geom <- cont_lines %>%
            dplyr::select(dplyr::any_of("geometry")) %>%
            sf::st_cast("LINESTRING") %>%
            sf::st_cast("POLYGON") %>%
            sf::st_union() %>%
            sf::st_cast("MULTIPOLYGON")

          sf::st_sf(
            level = as.numeric(lvl),
            geometry = sf::st_sfc(geom, crs = sf::st_crs(contours_sf))
          )
        },
        error = function(e) {
          warning(
            "Failed to build polygon for level ",
            lvl,
            ": ",
            conditionMessage(e)
          )
          NULL
        }
      )
    }
  )

  poly_list <- purrr::compact(poly_list)

  if (length(poly_list) == 0) {
    warning("No isopleths could be polygonized")
    return(empty_iso(x))
  }

  out <- dplyr::bind_rows(poly_list) %>%
    dplyr::mutate(area = sf::st_area(.data$geometry), .after = "level")

  sf::st_as_sf(out)
}
