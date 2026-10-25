#' Quantify the home range using dynamic Brownian bridges
#'
#' These functions estimate the utilisation distribution (UD) of each track
#' with a dynamic Brownian bridge movement model (dBBMM, Kranstauber et al.
#' 2012) or a dynamic bivariate Gaussian bridge (dBGB, Kranstauber et al.
#' 2014). Unlike [hr_tt_kde()], which treats locations as independent, bridges
#' model the movement between consecutive locations, with a motion variance
#' estimated along the track in a sliding window (so that, e.g., resting and
#' travelling contribute differently). dBGB further splits the motion variance
#' into components parallel and orthogonal to the direction of movement. They
#' are wrappers around [move2utils::mt_dbbmm_ud()] and
#' [move2utils::mt_dbgb_ud()], which require the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' @details Bridges link consecutive events within a track, so the UD is
#' estimated for each track: `x` must be either ungrouped, or grouped by its
#' track id column only. `x` must be ordered by time within each track (see
#' [tt_order_time()]). Events with an empty geometry (i.e. no location) are
#' ignored.
#'
#' By default, the UDs are estimated on the same grid as [hr_tt_kde()] would
#' use for `x` (the extent of all the locations, expanded by 100% of the range
#' on each side, with approximately 1000 cells), so that UDs estimated with
#' the different methods can be compared (e.g. with [hr_tt_ud_overlap()]).
#' The grid must be large enough to contain the bridges (which can extend well
#' beyond the locations, e.g. across long gaps between events); if it is not,
#' an error is given, and a larger `bbox` should be used. For
#' longitude/latitude data, the bridges are computed in a local metric
#' projection, and the UD is then projected back onto the grid.
#'
#' Further arguments of [move2utils::mt_dbbmm_ud()] and
#' [move2utils::mt_dbgb_ud()] (e.g. `time_step`) can be passed through `...`.
#'
#' If `levels` is set, the isopleths for the specified levels are returned
#' instead of the full UDs, as in [hr_tt_kde()].
#'
#' @param x A `move2` object, either ungrouped or grouped by its track id
#'   column.
#' @param location_error The error of the locations (the standard deviation
#'   of the position, as a distance). Either a `units` object (e.g.
#'   `as_units(20, "m")`) with one value for all events or one value per event,
#'   the name of a column of `x` with the errors in metres, or `NULL` (the
#'   default) to treat locations as exact. See
#'   [move2utils::mt_dbbmm_variance()] for other options.
#' @param window_size The number of events in the sliding window used to
#'   estimate the motion variance (an odd number).
#' @param margin The number of events at each end of the window that are not
#'   used as breakpoints when looking for changes in the motion variance (an
#'   odd number).
#' @param bbox A named vector of four elements (`xmin`, `ymin`, `xmax`,
#'   `ymax`) defining the grid shared by all tracks. If `NULL`, the grid of
#'   [hr_tt_kde()] is used (see Details).
#' @param res The resolution of the grid (in the units of the projection of
#'   `x`). If `NULL`, the grid has approximately 1000 cells.
#' @param levels A vector of levels for the isopleths, as numbers between 0
#'   and 1. If `NULL` (the default), the full UDs are returned.
#' @param ... Further arguments passed to [move2utils::mt_dbbmm_ud()] or
#'   [move2utils::mt_dbgb_ud()].
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#'   `NULL`, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
#'   [hr_tt_ud_iso()]), with columns:
#' - the track id column of `x`: the ids of the tracks
#' - `method`: the method used to estimate the home range (`"dbbmm"` or
#'   `"dbgb"`)
#' - `window_size` and `margin`: the values used for the sliding window
#' - `xmin`, `ymin`, `xmax`, `ymax` and `res`: the extent and resolution of
#'   the grid
#' - `ud` (if `levels` is `NULL`): the UDs, as a list of `terra::SpatRaster`
#'   objects with a layer named `ud` whose values sum to 1
#' - `level`, `area` and `geometry` (if `levels` is set): the isopleths, see
#'   [hr_tt_ud_iso()]
#' @references Kranstauber, B., Kays, R., LaPoint, S. D., Wikelski, M. & Safi,
#'   K. (2012). A dynamic Brownian bridge movement model to estimate
#'   utilization distributions for heterogeneous animal movement. *Journal of
#'   Animal Ecology*, 81, 738-746. \doi{10.1111/j.1365-2656.2012.01955.x}
#'
#'   Kranstauber, B., Safi, K. & Bartumeus, F. (2014). Bivariate Gaussian
#'   bridges: directional factorization of diffusion in Brownian bridge
#'   models. *Movement Ecology*, 2, 5. \doi{10.1186/2051-3933-2-5}
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # project the data to a metric projection, as the toy dataset spans a large
#' # area
#' x <- sf::st_transform(example_tt, "+proj=eqearth")
#' ud_dbbmm <- hr_tt_dbbmm(
#'   x,
#'   location_error = as_units(1000, "m"),
#'   window_size = 3,
#'   margin = 1
#' )
#' ud_dbbmm
#' # the UDs are on the same grid as those from hr_tt_kde(), so they can be
#' # compared
#' ud_kde <- hr_tt_kde(x)
#' hr_tt_ud_overlap(ud_dbbmm$ud[[1]], ud_kde$ud[[1]])
hr_tt_dbbmm <- function(
  x,
  location_error = NULL,
  window_size = 31,
  margin = 11,
  bbox = NULL,
  res = NULL,
  levels = NULL,
  ...
) {
  check_move2utils("hr_tt_dbbmm") # nolint: object_usage_linter.
  hr_tt_bridge(
    x,
    fn = move2utils::mt_dbbmm_ud,
    method = "dbbmm",
    location_error = location_error,
    window_size = window_size,
    margin = margin,
    bbox = bbox,
    res = res,
    levels = levels,
    ...
  )
}

#' @rdname hr_tt_dbbmm
#' @export
hr_tt_dbgb <- function(
  x,
  location_error = NULL,
  window_size = 31,
  margin = 15,
  bbox = NULL,
  res = NULL,
  levels = NULL,
  ...
) {
  check_move2utils("hr_tt_dbgb") # nolint: object_usage_linter.
  hr_tt_bridge(
    x,
    fn = move2utils::mt_dbgb_ud,
    method = "dbgb",
    location_error = location_error,
    window_size = window_size,
    margin = margin,
    bbox = bbox,
    res = res,
    levels = levels,
    ...
  )
}

#' Estimate the UD of each track with a move2utils bridge model
#'
#' Shared by [hr_tt_dbbmm()] and [hr_tt_dbgb()].
#'
#' @param fn The `move2utils` function computing the UDs.
#' @param method The name of the method, stored in the `method` column.
#' @inheritParams hr_tt_dbbmm
#' @returns See [hr_tt_dbbmm()].
#' @keywords internal
#' @noRd
hr_tt_bridge <- function(
  x,
  fn,
  method,
  location_error,
  window_size,
  margin,
  bbox,
  res,
  levels,
  ...
) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  track_col <- move2::mt_track_id_column(x)
  if (inherits(x, "grouped_df")) {
    if (!identical(dplyr::group_vars(x), track_col)) {
      stop(
        "x must be ungrouped, or grouped by its track id column ('",
        track_col, "') only, as bridges link consecutive events of a track"
      )
    }
    x <- dplyr::ungroup(x)
  }
  check_time_ordered(x) # nolint: object_usage_linter.
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }

  # events with an empty geometry have no location to contribute to the UD
  x <- x[!sf::st_is_empty(x), ]

  # the grid shared by all tracks, by default the same as in hr_tt_kde()
  if (is.null(bbox)) {
    bbox <- expand_kde_bbox(sf::st_bbox(x)) # nolint: object_usage_linter.
  } else {
    bbox <- normalise_kde_bbox(bbox) # nolint: object_usage_linter.
  }
  if (is.null(res)) {
    res <- kde_resolution(bbox) # nolint: object_usage_linter.
  }
  if (!is.numeric(res) || length(res) != 1 || !is.finite(res) || res <= 0) {
    stop("res must be a single finite, positive number")
  }
  bbox <- align_kde_bbox(bbox, res) # nolint: object_usage_linter.
  grid <- terra::rast(
    xmin = bbox[["xmin"]],
    xmax = bbox[["xmax"]],
    ymin = bbox[["ymin"]],
    ymax = bbox[["ymax"]],
    ncols = round((bbox[["xmax"]] - bbox[["xmin"]]) / res),
    nrows = round((bbox[["ymax"]] - bbox[["ymin"]]) / res),
    crs = sf::st_crs(x)$wkt
  )

  args <- units_to_move2utils(c( # nolint: object_usage_linter.
    list(
      raster = grid,
      location_error = location_error,
      window_size = window_size,
      margin = margin,
      verbose = FALSE
    ),
    list(...)
  ))
  uds <- tryCatch(
    do.call(fn, c(list(x), args)),
    error = function(e) {
      # move2utils suggests its ext argument, which is not used with a grid
      if (
        grepl(
          "grid not large enough|does not extent far enough",
          conditionMessage(e)
        )
      ) {
        stop(
          "the grid is not large enough to contain the bridges; ",
          "use a larger bbox",
          call. = FALSE
        )
      }
      stop(e)
    }
  )

  # one row per track, in the same order (and with the same character ids) as
  # hr_tt_kde() for ungrouped data
  track_ids <- as.character(
    dplyr::group_keys(dplyr::group_by(x, .data[[track_col]]))[[1]]
  )
  ud_list <- lapply(track_ids, function(id) {
    ud <- if (terra::nlyr(uds) == 1) uds else uds[[id]]
    names(ud) <- "ud"
    terra::metags(ud) <- c(
      paste0("id = ", id),
      paste0("method = ", method)
    )
    ud
  })
  names(ud_list) <- track_ids

  res_tbl <- tibble::tibble(
    track_id = track_ids,
    method = method,
    window_size = window_size,
    margin = margin,
    xmin = bbox[["xmin"]],
    ymin = bbox[["ymin"]],
    xmax = bbox[["xmax"]],
    ymax = bbox[["ymax"]],
    res = res,
    ud = ud_list
  )
  names(res_tbl)[1] <- track_col
  class(res_tbl) <- c("hr_tt_ud_tbl", class(res_tbl))

  if (!is.null(levels)) {
    res_tbl <- hr_tt_ud_iso(res_tbl, levels) # nolint: object_usage_linter.
  }
  res_tbl
}
