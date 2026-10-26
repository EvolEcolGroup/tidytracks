#' Create isopleths from utilisation distributions
#'
#' This method can be applied to a whole tibble of UDs, or to an individual UD.
#'
#' @param x either a tibble of class `hr_tt_ud_tbl`, as created by
#'   [hr_tt_kde()], or a `SpatRaster` object from the `ud` column of a
#'   `hr_tt_ud_tbl` tibble.
#' @param levels numeric vector of isopleth levels to create. Default is
#'   `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels should be
#'   between 0 and 1.
#' @param ci_level The confidence level of the confidence intervals of the
#'   areas of the isopleths, which are computed for the UDs estimated with
#'   `ctmm` (i.e. a table with a `ud_ctmm` column, as returned by
#'   [hr_tt_akde()] and [hr_tt_akde_pop()]); it is ignored for other UDs.
#'   Default is 0.95.
#' @return If `x` is a `SpatRaster`, an `sf` object with one row per level and
#'   columns `level`, `area` (the area of the isopleth) and `geometry` (a
#'   `MULTIPOLYGON` for the isopleth). If `x` is a tibble, an `sf` tibble of
#'   class `hr_tt_poly_tbl` with the columns of `x` (except `ud` and
#'   `ud_ctmm`) and, for each UD, one row per level with these three columns.
#'   For the UDs estimated with `ctmm`, the columns `area_low` and `area_high`
#'   (the confidence interval of the home range area at each level, as
#'   estimated by `ctmm`) are added after `area` (in a table that combines
#'   them with other UDs, e.g. from [hr_tt_kde()], the other UDs get `NA`).
#' @export
#' @family home_range
#' @examples
#' example_kde <- hr_tt_kde(example_tt)
#' example_iso <- hr_tt_ud_iso(example_kde)
#' example_iso
#'
#' # now plot the isopleths
#' library(ggplot2)
#' ggplot(example_iso) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
hr_tt_ud_iso <- function(x, levels = c(0.50, 0.95), ci_level = 0.95) {
  UseMethod("hr_tt_ud_iso")
}

#' @export
#' @rdname hr_tt_ud_iso
# Note that we have a generic method for a tibble as the hr_tt_ud_tbl
# class is lost on group_map operations
hr_tt_ud_iso.tbl_df <- function(
  x,
  levels = c(0.50, 0.95),
  ci_level = 0.95
) {
  stopifnot_hr_tt_ud_table(x) # nolint: object_usage_linter.
  # Work with a plain list locally while preserving a loaded object's packing.
  x <- unwrap_ud_column(x) # nolint: object_usage_linter.

  levels <- sort(levels)
  # the UDs estimated with ctmm (by hr_tt_akde() or hr_tt_akde_pop()), which
  # come with their ctmm UD objects in column ud_ctmm, get the confidence
  # intervals of the areas of their isopleths
  with_ci <- "ud_ctmm" %in% names(x)
  if (with_ci) {
    check_probability_arg(ci_level, "ci_level") # nolint: object_usage_linter.
    # the intervals are computed by summary() of the ctmm UD objects, whose
    # method needs ctmm
    check_ctmm_installed() # nolint: object_usage_linter.
  }

  # the isopleths of each UD (an sf object for each row)
  res_tbl <- x %>%
    dplyr::mutate(iso = purrr::map(.data$ud, hr_tt_ud_iso, levels = levels))
  if (with_ci) {
    res_tbl$iso <- purrr::map2(
      res_tbl$iso,
      res_tbl$ud_ctmm,
      akde_iso_area_ci, # nolint: object_usage_linter.
      ci_level = ci_level
    )
  }
  # the UDs (including the ctmm UD objects) are replaced by their isopleths
  res_tbl <- res_tbl %>%
    dplyr::select(-dplyr::any_of(c("ud", "ud_ctmm"))) %>%
    tidyr::unnest(dplyr::any_of("iso"))

  res_tbl <- sf::st_as_sf(res_tbl)
  class(res_tbl) <- c("hr_tt_poly_tbl", class(res_tbl))
  res_tbl
}


#' @export
#' @rdname hr_tt_ud_iso
hr_tt_ud_iso.SpatRaster <- function(
  x,
  levels = c(0.50, 0.95),
  ci_level = 0.95
) {
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
    terra::as.contour(
      hr_tt_cud(x), # nolint: object_usage_linter.
      levels = levels
    ),
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
          rings <- cont_lines %>%
            dplyr::select(dplyr::any_of("geometry")) %>%
            sf::st_cast("LINESTRING") %>%
            sf::st_cast("POLYGON") %>%
            sf::st_geometry()
          # Contour lines of a surface never cross, so a location lies within
          # the isopleth if it is inside an odd number of rings: a ring nested
          # within another ring is a hole (e.g. a low-density area surrounded
          # by high density), which a union of the rings would fill in.
          geom <- rings[1]
          for (i in seq_along(rings)[-1]) {
            geom <- sf::st_sym_difference(geom, rings[i])
          }
          geom <- geom %>%
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


# deprecated function for backward compatibility
#' @name hr_tt_ud_iso
#' @export
hr_ud_iso <- function(x, levels = c(0.50, 0.95)) {
  warning(
    "hr_ud_iso is deprecated. Please use hr_tt_ud_iso instead.",
    call. = FALSE
  )
  hr_tt_ud_iso(x = x, levels = levels)
}
