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
#' @details Each UD has one row per level: an isopleth that cannot be drawn is
#'   returned with an empty geometry and an `NA` area, with a warning that says
#'   why, and what to do about it. The most common case is an isopleth at a
#'   level that is smaller than the share of the UD held by the cells with its
#'   highest value (e.g. a 50% isopleth of a UD with 90% of it in a single
#'   cell), which has no cell within it. This happens for UDs estimated on
#'   grids that are coarse relative to the UD (e.g. a kernel bandwidth that is
#'   small relative to the cells, or an animal that spends most of its time at
#'   one place): use a finer grid. More generally, the isopleths are drawn
#'   between the centres of the cells, so they are only accurate on grids that
#'   are fine relative to the UD. Other cases are a 0% isopleth, and UDs
#'   without values (e.g. all `NA`) or with infinite values.
#' @return If `x` is a `SpatRaster`, an `sf` object with one row per level and
#'   columns `level`, `area` (the area of the isopleth) and `geometry` (a
#'   `MULTIPOLYGON` for the isopleth, empty if it cannot be drawn on the grid,
#'   see Details). If `x` is a tibble, an `sf` tibble of
#'   class `hr_tt_poly_tbl` with the columns of `x` (except `ud` and
#'   `ud_ctmm`) and, for each UD, one row per level with these three columns.
#'   For the UDs estimated with `ctmm`, the columns `area_low` and `area_high`
#'   (the confidence interval of the home range area at each level, as
#'   estimated by `ctmm`) are added after `area` (in a table that combines
#'   them with other UDs, e.g. from [hr_tt_kde()], the other UDs get `NA`).
#' @export
#' @family home_range
#' @examples
#' # project example_tt (in longitude/latitude) to an equal-area projection
#' example_proj <- sf::st_transform(example_tt, "+proj=laea +lon_0=-1 +lat_0=0")
#' example_kde <- hr_tt_kde(example_proj)
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
  # the levels that cannot be drawn on the grid of each UD (kept aside, as
  # adding the confidence intervals drops the attributes of the isopleths)
  not_drawn <- lapply(iso, attr, "not_drawn")
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
  isopleth_table(x, iso, not_drawn = not_drawn)
}


#' @export
#' @rdname hr_tt_ud_iso
hr_tt_ud_iso.SpatRaster <- function(
  x,
  levels = c(0.50, 0.95),
  ci_level = 0.95
) {
  iso <- raster_isopleths(x, levels = levels)
  warn_isopleths_not_drawn(list(attr(iso, "not_drawn")))
  if (nrow(iso) == 0) {
    return(iso)
  }
  out <- dplyr::mutate(
    iso,
    area = sf::st_area(.data$geometry),
    .after = "level"
  )
  # an isopleth that cannot be drawn has no area
  out$area[sf::st_is_empty(out)] <- NA
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
#' @returns An `sf` data frame with columns `level`, `area` (`NA` for now) and
#'   `geometry` (in the CRS of `x`), with one row per level (see `iso_sf()`).
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

  # the cumulative UD, as a matrix laid out as cud_isopleths() expects it
  # (subsetting the layer creates a new raster, which takes a while, so it is
  # only done if there are other layers)
  ud <- raster_xy_matrix(if (terra::nlyr(x) == 1) x else x[["ud"]])
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
  iso_sf(iso, levels, crs_cache$crs)
}

#' Isopleths as an sf data frame
#'
#' @param iso the isopleths, as returned by `cud_isopleths()`.
#' @param levels the levels of the isopleths that were asked for, sorted.
#' @param crs the CRS of the isopleths.
#' @returns An `sf` data frame with columns `level`, `area` (`NA`) and
#'   `geometry`, with one row per level (a repeated level gives a single
#'   row): a level without an isopleth gets an empty multipolygon. The levels
#'   without an isopleth, and why, are in the attribute `not_drawn` (see
#'   `isopleths_not_drawn()`), for `warn_isopleths_not_drawn()`.
#' @keywords internal
#' @noRd
iso_sf <- function(iso, levels, crs) {
  levels <- unique(levels)
  # an empty multipolygon for each level, replaced by its isopleth if it has
  # one
  geometry <- rep(list(sf::st_multipolygon()), length(levels))
  drawn <- match(iso$level, levels)
  for (i in seq_along(drawn)) {
    geometry[[drawn[i]]] <- iso$geometry[[i]]
  }
  out <- sf::st_sf(
    level = levels,
    area = rep(NA_real_, length(levels)),
    geometry = sf::st_sfc(geometry, crs = crs)
  )
  # every level without an isopleth is reported (cud_isopleths() records why;
  # this is a safeguard for any other case)
  not_drawn <- iso$not_drawn
  if (is.null(not_drawn)) {
    not_drawn <- isopleths_not_drawn()
  }
  unexplained <- setdiff(levels[sf::st_is_empty(out)], not_drawn$level)
  not_drawn <- rbind(
    not_drawn,
    isopleths_not_drawn(unexplained, "no_contour")
  )
  attr(out, "not_drawn") <- not_drawn
  out
}

#' The isopleths that cannot be drawn, and why
#'
#' Internal function: the isopleths (of a UD, or a home range) that cannot be
#' drawn are returned with an empty geometry and an `NA` area, so that each
#' UD has one row per level; their levels are recorded with the reason, for
#' `warn_isopleths_not_drawn()`.
#'
#' @param levels the levels of the isopleths.
#' @param reason why they cannot be drawn: one of the reasons of
#'   `isopleth_not_drawn_reason()`.
#' @param detail details of the reason (e.g. an error message), or `NA`.
#' @returns A data frame with columns `level`, `reason` and `detail`.
#' @keywords internal
#' @noRd
isopleths_not_drawn <- function(
  levels = numeric(0),
  reason = character(0),
  detail = NA_character_
) {
  data.frame(
    level = as.numeric(levels),
    reason = rep(as.character(reason), length.out = length(levels)),
    detail = rep(as.character(detail), length.out = length(levels))
  )
}

#' Why an isopleth cannot be drawn, and what to do about it
#'
#' @param reason the reason (see the code for the possible values).
#' @param detail details of the reason, or `NA`.
#' @returns A sentence for the warning of `warn_isopleths_not_drawn()`.
#' @keywords internal
#' @noRd
isopleth_not_drawn_reason <- function(reason, detail = NA_character_) {
  detail <- if (is.na(detail)) "" else paste0(" (", detail, ")")
  switch(reason,
    # isopleths of UDs (cud_isopleths())
    highest_cells = paste0(
      "the cells with the highest value of the UD hold more of it than the ",
      "level", detail, ", so no cell is within the isopleth; use a UD ",
      "estimated on a finer grid (for hr_tt_kde(), a smaller res or a larger ",
      "h)"
    ),
    ud_no_values = paste0(
      "the UD has no values (all its cells are NA); check how it was ",
      "estimated"
    ),
    ud_infinite = "the UD has infinite values; check how it was estimated",
    zero_level = "a 0% isopleth encloses none of the UD; use a level above 0",
    no_contour = paste0(
      "no contour line could be drawn at the level", detail, "; check that ",
      "the UD has finite values, or use a UD estimated on a finer grid"
    ),
    no_polygon = paste0(
      "its contour lines could not be turned into polygons", detail, "; use ",
      "a UD estimated on a finer grid, or project the data to a planar CRS"
    ),
    no_area = paste0(
      "its contour lines enclose no area", detail, "; use a UD estimated on ",
      "a finer grid"
    ),
    # minimum convex polygons (hr_tt_mcp())
    mcp_no_area = paste0(
      "the locations within it (the proportion of the locations closest to ",
      "their centroid) are fewer than three, or are on a line, so their ",
      "convex hull has no area; use a larger level"
    ),
    # tracks without a UD (hr_tt_dbbmm())
    dbbmm_few_locations = paste0(
      "the track has fewer locations than window_size, so it has no UD; use ",
      "a smaller window_size"
    ),
    # local convex hulls (hr_tt_locoh())
    locoh_no_area = paste0(
      "its hulls have no area, as their locations are at the same place or ",
      "on a line; use a larger level, a larger n, or a buffer"
    ),
    stop("unknown reason for an isopleth not drawn: ", reason)
  )
}

#' Warn about the isopleths that cannot be drawn
#'
#' A single warning for all the isopleths (of UDs, or home ranges) that cannot
#' be drawn, with one line per UD and reason: its levels, why they cannot be
#' drawn, and what to do about it.
#'
#' @param not_drawn a list with, for each UD (or group), a data frame from
#'   `isopleths_not_drawn()`, or `NULL`.
#' @param labels the names of the UDs (or groups), or `NULL` for a single UD.
#' @param max_lines the largest number of lines in the warning.
#' @returns `NULL`, invisibly, with a warning if any isopleth cannot be drawn.
#' @keywords internal
#' @noRd
warn_isopleths_not_drawn <- function(not_drawn, labels = NULL, max_lines = 10) {
  has_any <- vapply(not_drawn, function(nd) NROW(nd) > 0, logical(1))
  if (!any(has_any)) {
    return(invisible(NULL))
  }
  percent <- function(p) paste0(signif(p * 100, 3), "%")
  # one line per UD and reason, with its levels
  details <- unlist(lapply(which(has_any), function(i) {
    nd <- not_drawn[[i]]
    nd <- nd[order(nd$level), , drop = FALSE]
    key <- paste(nd$reason, nd$detail)
    vapply(
      unique(key),
      function(k) {
        same <- nd[key == k, , drop = FALSE]
        paste0(
          "* ",
          if (!is.null(labels)) paste0("'", labels[i], "', "),
          paste(percent(same$level), collapse = ", "),
          ": ",
          isopleth_not_drawn_reason(same$reason[1], same$detail[1])
        )
      },
      character(1),
      USE.NAMES = FALSE
    )
  }))
  # a long list (e.g. with many tracks) is cut short
  if (length(details) > max_lines) {
    details <- c(
      details[seq_len(max_lines)],
      paste0("* ... and ", length(details) - max_lines, " more")
    )
  }
  warning(
    "Some isopleths cannot be drawn, so they are returned with an empty ",
    "geometry and an NA area:\n",
    paste(details, collapse = "\n"),
    call. = FALSE
  )
  invisible(NULL)
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
#' @param not_drawn a list with the isopleths that cannot be drawn for each UD
#'   (the `not_drawn` attributes of `iso`), for the warning.
#' @returns An `sf` tibble of class `hr_tt_poly_tbl`.
#' @keywords internal
#' @noRd
isopleth_table <- function(x, iso, not_drawn = lapply(iso, attr, "not_drawn")) {
  # warn about the isopleths that cannot be drawn, naming their UDs as
  # hr_tt_kde() names them (by the keys of their groups)
  key_columns <- hr_key_columns(x) # nolint: object_usage_linter.
  warn_isopleths_not_drawn(
    not_drawn,
    labels = hr_group_labels(x[key_columns]) # nolint: object_usage_linter.
  )
  # assigned directly rather than with mutate(), which would evaluate it
  # within each group of a grouped x (e.g. from hr_tt_ud_sum())
  x$iso <- iso
  res_tbl <- tidyr::unnest(x, dplyr::any_of("iso"))
  # the geometry is named, as a key of the UDs may be an sfc column (e.g. from
  # group_by_meta())
  res_tbl <- sf::st_as_sf(res_tbl, sf_column_name = "geometry")
  if (nrow(res_tbl) > 0) {
    res_tbl$area <- sf::st_area(res_tbl)
    # an isopleth that cannot be drawn has no area
    res_tbl$area[sf::st_is_empty(res_tbl)] <- NA
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
#' @param cud a matrix with the cumulative UD, with one row per column of
#'   cells (from west to east) and one column per row of cells (from south to
#'   north), as for [grDevices::contourLines()] (see `raster_xy_matrix()`).
#' @param x,y the coordinates of the centres of the columns, and of the rows
#'   from south to north.
#' @param res the size of the cells, along x and along y.
#' @param levels the levels of the isopleths, sorted (a level that is
#'   repeated gives a single isopleth).
#' @param ops_crs the CRS for the geometric operations: `sf::NA_crs_` for
#'   data, so that GEOS carries them out without sf looking up the parameters
#'   of the CRS for each of them, or the CRS for longitudes and latitudes, so
#'   that sf carries them out as it does for such data (with s2, on the
#'   sphere, by default).
#' @param cud_raster a function returning the cumulative UD as a
#'   `SpatRaster`, used for rasters of more than 100,000 cells.
#' @returns A list with `level` (a numeric vector) and `geometry` (an `sfc` of
#'   multipolygons, with the CRS `ops_crs`) for the isopleths that can be
#'   drawn, and `not_drawn`, the levels of the others with the reason (see
#'   `isopleths_not_drawn()`).
#' @keywords internal
#' @noRd
cud_isopleths <- function(cud, x, y, res, levels, ops_crs, cud_raster) {
  # a repeated level would give each of its contour lines twice, which would
  # cancel each other out in the isopleth
  levels <- unique(levels)
  # The levels of the isopleths that cannot be drawn are recorded with the
  # reason, for a warning, rather than silently dropped. A level smaller than
  # the cumulative UD of every cell (e.g. 50%, when the cell with the highest
  # value holds 90% of the UD) has no cell within its isopleth, so it has no
  # contour line (as in hr_tt_ud_overlap(), a cell is within the isopleth for
  # a level if its cumulative UD is at most that level).
  out <- list(
    level = numeric(0),
    geometry = sf::st_sfc(crs = ops_crs),
    not_drawn = isopleths_not_drawn()
  )
  # a UD without values (e.g. all NA), or with infinite values, has no
  # isopleths
  if (all(is.na(cud)) || any(is.infinite(cud))) {
    reason <- if (all(is.na(cud))) "ud_no_values" else "ud_infinite"
    out$not_drawn <- isopleths_not_drawn(levels, reason)
    return(out)
  }
  # a 0% isopleth encloses none of the UD
  out$not_drawn <- isopleths_not_drawn(levels[levels == 0], "zero_level")
  levels <- levels[levels > 0]
  min_level <- min(cud, na.rm = TRUE)
  in_grid <- levels >= min_level
  out$not_drawn <- rbind(
    out$not_drawn,
    isopleths_not_drawn(
      levels[!in_grid],
      "highest_cells",
      paste0(
        "the smallest level that can be drawn is ",
        signif(min_level * 100, 3),
        "%"
      )
    )
  )
  levels <- levels[in_grid]
  if (length(levels) == 0) {
    return(out)
  }
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
    cud <- raster_xy_matrix(sampled)
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
  z <- rbind(cud[1, ], cud, cud[nrow(cud), ])
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
    error = function(e) e
  )
  if (inherits(lines, "error")) {
    out$not_drawn <- rbind(
      out$not_drawn,
      isopleths_not_drawn(levels, "no_contour", conditionMessage(lines))
    )
    return(out)
  }
  line_level <- vapply(lines, function(l) l$level, numeric(1))
  line_coords <- lapply(lines, function(l) cbind(l$x, l$y))
  # the levels without a contour line
  out$not_drawn <- rbind(
    out$not_drawn,
    isopleths_not_drawn(setdiff(levels, line_level), "no_contour")
  )

  # 2) The isopleth for each level (see ops_crs for the CRS used); the lines
  # are matched to the levels by value, rather than through the names given
  # by split(), which can round a level (e.g. 1/3)
  poly_list <- lapply(unique(line_level), function(lvl) {
    tryCatch(
      {
        rings <- sf::st_sfc(
          lapply(line_coords[line_level == lvl], sf::st_linestring),
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
        # rings that enclose no area (e.g. collapsed onto a line) give an
        # empty isopleth
        if (sf::st_is_empty(geom)) {
          return(list(level = lvl, reason = "no_area", detail = NA_character_))
        }
        list(level = lvl, geometry = geom)
      },
      error = function(e) {
        list(level = lvl, reason = "no_polygon", detail = conditionMessage(e))
      }
    )
  })
  failed <- vapply(poly_list, function(p) is.null(p$geometry), logical(1))
  for (p in poly_list[failed]) {
    out$not_drawn <- rbind(
      out$not_drawn,
      isopleths_not_drawn(p$level, p$reason, p$detail)
    )
  }
  poly_list <- poly_list[!failed]
  if (length(poly_list) > 0) {
    out$level <- vapply(poly_list, function(p) p$level, numeric(1))
    out$geometry <- do.call(c, lapply(poly_list, function(p) p$geometry))
  }
  out
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

#' The values of a raster as a matrix laid out for contour lines
#'
#' Internal function: the values of a raster with a single layer, as a
#' matrix with one row per column of cells (from west to east) and one
#' column per row of cells (from south to north), as for
#' [grDevices::contourLines()] and `cud_isopleths()`, and as `hr_tt_kde()`
#' estimates the UD. `xy_matrix_values()` does the reverse.
#'
#' @param r a `SpatRaster` with a single layer.
#' @returns A numeric matrix with `ncol(r)` rows and `nrow(r)` columns.
#' @keywords internal
#' @noRd
raster_xy_matrix <- function(r) {
  # the values of a raster are row by row, from the north: as the columns of
  # a matrix, each column is a row of cells, from the north
  values <- terra::values(r, mat = FALSE)
  dim(values) <- c(terra::ncol(r), terra::nrow(r))
  values[, rev(seq_len(ncol(values))), drop = FALSE]
}

#' The values of a matrix laid out for contour lines, in the order of a raster
#'
#' Internal function, the reverse of `raster_xy_matrix()`: the values of a
#' matrix with one row per column of cells (from west to east) and one
#' column per row of cells (from south to north), in the order in which
#' they fill a raster (row by row, from the north).
#'
#' @param m a numeric matrix, laid out as from `raster_xy_matrix()`.
#' @returns A numeric vector of the values of `m`, in the order of the cells
#'   of the raster.
#' @keywords internal
#' @noRd
xy_matrix_values <- function(m) {
  values <- m[, rev(seq_len(ncol(m))), drop = FALSE]
  dim(values) <- NULL
  values
}
