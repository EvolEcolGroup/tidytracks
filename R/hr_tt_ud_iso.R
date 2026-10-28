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

  # The isopleths of each UD, without their areas. sf looks up the
  # parameters of the CRS (with PROJ) every time it is given a CRS, which
  # takes longer than the isopleths of a small UD, so the CRS is only looked
  # up when it changes from one UD to the next, and the areas are computed
  # for all UDs at once (in isopleth_table()).
  crs_cache <- new.env()
  iso <- lapply(x$ud, function(ud) {
    raster_isopleths(ud, levels = levels, crs_cache = crs_cache)
  })
  if (with_ci) {
    iso <- purrr::map2(
      iso,
      x$ud_ctmm,
      akde_iso_area_ci, # nolint: object_usage_linter.
      ci_level = ci_level
    )
    x$ud_ctmm <- NULL
  }
  # the UDs (including the ctmm UD objects) are replaced by their isopleths
  x$ud <- NULL
  isopleth_table(x, iso)
}


#' @export
#' @rdname hr_tt_ud_iso
hr_tt_ud_iso.SpatRaster <- function(
  x,
  levels = c(0.50, 0.95),
  ci_level = 0.95
) {
  iso <- raster_isopleths(x, levels = levels)
  if (nrow(iso) == 0) {
    return(iso)
  }
  out <- dplyr::mutate(
    iso,
    area = sf::st_area(.data$geometry),
    .after = "level"
  )
  sf::st_as_sf(out)
}

#' Isopleths of a UD stored in a SpatRaster
#'
#' Internal function used by the methods of [hr_tt_ud_iso()]: it checks the
#' raster, computes its cumulative UD, and returns its isopleths, without
#' their areas.
#'
#' @param x a `SpatRaster` with a layer named `ud`.
#' @param levels the levels of the isopleths.
#' @param crs_cache an environment, shared between the calls for several
#'   rasters, which holds the last CRS looked up (in `wkt` and `crs`), or
#'   `NULL`.
#' @returns An `sf` data frame with columns `level`, `area` (`NA` for now; an
#'   empty `numeric` if there are no isopleths) and `geometry` (in the CRS of
#'   `x`).
#' @keywords internal
#' @noRd
raster_isopleths <- function(x, levels, crs_cache = NULL) {
  if (any(levels < 0 | levels > 1)) {
    stop("levels should be between 0 and 1")
  }
  levels <- sort(levels)

  # check that x has a ud layer
  if (!("ud" %in% names(x))) {
    stop("x must have a layer named 'ud'")
  }

  # look up the CRS, unless it is the same as for the previous raster
  wkt <- terra::crs(x)
  if (is.null(crs_cache) || !identical(crs_cache$wkt, wkt)) {
    if (is.null(crs_cache)) {
      crs_cache <- new.env()
    }
    crs_cache$wkt <- wkt
    crs_cache$crs <- sf::st_crs(wkt)
    crs_cache$longlat <- isTRUE(sf::st_is_longlat(crs_cache$crs))
  }

  # the cumulative UD, as a matrix laid out as the raster (subsetting the
  # layer creates a new raster, which takes a while, so it is only done if
  # there are other layers)
  ud <- as.matrix(if (terra::nlyr(x) == 1) x else x[["ud"]], wide = TRUE)
  cud <- hr_tt_cud(ud) # nolint: object_usage_linter.
  iso <- cud_isopleths(
    cud,
    x = terra::xFromCol(x, seq_len(ncol(x))),
    y = terra::yFromRow(x, rev(seq_len(nrow(x)))),
    res = terra::res(x),
    levels = levels,
    ops_crs = if (crs_cache$longlat) crs_cache$crs else sf::NA_crs_,
    cud_raster = function() hr_tt_cud(x) # nolint: object_usage_linter.
  )
  iso_sf(iso, crs_cache$crs)
}

#' Isopleths as an sf data frame
#'
#' @param iso the isopleths, as returned by `cud_isopleths()`.
#' @param crs the CRS of the isopleths.
#' @returns An `sf` data frame with columns `level`, `area` (`NA`, or an empty
#'   `numeric` if there are no isopleths) and `geometry`.
#' @keywords internal
#' @noRd
iso_sf <- function(iso, crs) {
  if (is.null(iso)) {
    return(sf::st_sf(
      level = numeric(0),
      area = numeric(0),
      geometry = sf::st_sfc(crs = crs)
    ))
  }
  sf::st_sf(
    level = iso$level,
    area = NA_real_,
    geometry = sf::st_sfc(iso$geometry, crs = crs)
  )
}

#' Table of isopleths
#'
#' Internal function: combines a table with one row per UD and the isopleths
#' of each UD into a table with one row per UD and level, as returned by
#' [hr_tt_ud_iso()], and computes the areas of all the isopleths at once.
#'
#' @param x a tibble with one row per UD (without the `ud` column).
#' @param iso a list with the isopleths of each UD, as returned by
#'   `iso_sf()`.
#' @returns An `sf` tibble of class `hr_tt_poly_tbl`.
#' @keywords internal
#' @noRd
isopleth_table <- function(x, iso) {
  # assigned directly rather than with mutate(), which would evaluate it
  # within each group of a grouped x (e.g. from hr_tt_ud_sum())
  x$iso <- iso
  res_tbl <- tidyr::unnest(x, dplyr::any_of("iso"))
  res_tbl <- sf::st_as_sf(res_tbl)
  if (nrow(res_tbl) > 0) {
    res_tbl$area <- sf::st_area(res_tbl)
  }
  class(res_tbl) <- c("hr_tt_poly_tbl", class(res_tbl))
  res_tbl
}

#' Isopleths of a cumulative UD
#'
#' Internal function: computes the contour lines of a cumulative UD at the
#' given levels and turns them into multipolygons. A location lies within
#' the isopleth for a level if it is inside an odd number of the contour lines
#' for that level (a contour line nested within another one is a hole).
#'
#' @param cud a matrix with the cumulative UD, laid out as the raster (rows
#'   from north to south).
#' @param x,y the coordinates of the centres of the columns, and of the rows
#'   from south to north.
#' @param res the size of the cells, along x and along y.
#' @param levels the levels of the isopleths, sorted.
#' @param ops_crs the CRS for the geometric operations: `sf::NA_crs_` for
#'   data, so that GEOS carries them out without sf looking up the parameters
#'   of the CRS for each of them, or the CRS for longitudes and latitudes, so
#'   that sf carries them out as it does for such data (with s2, on the
#'   sphere, by default).
#' @param cud_raster a function returning the cumulative UD as a
#'   `SpatRaster`, used for rasters of more than 100,000 cells.
#' @returns A list with `level` (a numeric vector) and `geometry` (an `sfc` of
#'   multipolygons, with the CRS `ops_crs`), or `NULL` (with a warning) if
#'   there are no isopleths.
#' @keywords internal
#' @noRd
cud_isopleths <- function(cud, x, y, res, levels, ops_crs, cud_raster) {
  # 1) The contour lines, each with its level. These are the lines that
  # terra::as.contour() would give, without building the SpatVector (which
  # takes much longer than the contours of a small raster): it calls
  # grDevices::contourLines() on the values of the raster, after sampling a
  # raster of more than 100,000 cells down to that size.
  if (length(cud) > 1e5) {
    sampled <- terra::spatSample(
      cud_raster(),
      size = 1e5,
      method = "regular",
      as.raster = TRUE,
      warn = FALSE
    )
    cud <- as.matrix(sampled, wide = TRUE)
    x <- terra::xFromCol(sampled, seq_len(ncol(sampled)))
    y <- terra::yFromRow(sampled, rev(seq_len(nrow(sampled))))
    res <- terra::res(sampled)
  }
  # The contour lines of an isopleth that reaches the edges of the grid would
  # end there, and could not be closed into the rings of the isopleth. So the
  # cumulative UD is padded with the values of the cells on the edges, out to
  # the edges of the grid, and just beyond them with a value above all the
  # levels: the contour lines then follow the edges of the grid, as do the
  # cells within the isopleth.
  z <- t(cud[rev(seq_len(nrow(cud))), , drop = FALSE])
  z <- rbind(z[1, ], z, z[nrow(z), ])
  z <- cbind(z[, 1], z, z[, ncol(z)])
  outside <- max(levels) + 1
  z <- cbind(outside, rbind(outside, z, outside), outside)
  pad <- function(centres, res) {
    edges <- c(centres[1] - res / 2, centres[length(centres)] + res / 2)
    c(edges[1] - res * 1e-6, edges[1], centres, edges[2], edges[2] + res * 1e-6)
  }
  lines <- tryCatch(
    grDevices::contourLines(
      x = pad(x, res[1]),
      y = pad(y, res[2]),
      z = z,
      levels = levels
    ),
    error = function(e) {
      warning("No isopleths could be computed: ", conditionMessage(e))
      NULL
    }
  )
  if (is.null(lines)) {
    return(NULL)
  }
  line_level <- vapply(lines, function(l) l$level, numeric(1))
  line_coords <- lapply(lines, function(l) cbind(l$x, l$y))
  if (length(line_level) == 0) {
    warning("No isopleths could be computed")
    return(NULL)
  }

  # 2) The isopleth for each level (see ops_crs for the CRS used)
  by_level <- split(seq_along(line_level), line_level)
  poly_list <- lapply(names(by_level), function(lvl) {
    tryCatch(
      {
        rings <- sf::st_sfc(
          lapply(line_coords[by_level[[lvl]]], sf::st_linestring),
          crs = ops_crs
        )
        rings <- sf::st_cast(rings, "POLYGON")
        # Contour lines of a surface never cross, so a location lies within
        # the isopleth if it is inside an odd number of rings: a ring nested
        # within another ring is a hole (e.g. a low-density area surrounded
        # by high density), which a union of the rings would fill in.
        geom <- rings[1]
        for (i in seq_along(rings)[-1]) {
          geom <- sf::st_sym_difference(geom, rings[i])
        }
        geom <- sf::st_cast(sf::st_union(geom), "MULTIPOLYGON")
        # st_cast() leaves the attributes of the sfc (including its CRS) on
        # the multipolygon itself, where they serve no purpose: drop them
        attributes(geom[[1]]) <- list(class = class(geom[[1]]))
        list(level = as.numeric(lvl), geometry = geom)
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
  })
  poly_list <- poly_list[!vapply(poly_list, is.null, logical(1))]

  if (length(poly_list) == 0) {
    warning("No isopleths could be polygonized")
    return(NULL)
  }
  list(
    level = vapply(poly_list, function(p) p$level, numeric(1)),
    geometry = do.call(c, lapply(poly_list, function(p) p$geometry))
  )
}

# deprecated function for backward compatibility
#' @rdname tidytracks-deprecated
#' @export
hr_ud_iso <- function(x, levels = c(0.50, 0.95)) {
  warning(
    "hr_ud_iso is deprecated. Please use hr_tt_ud_iso instead.",
    call. = FALSE
  )
  hr_tt_ud_iso(x = x, levels = levels)
}
