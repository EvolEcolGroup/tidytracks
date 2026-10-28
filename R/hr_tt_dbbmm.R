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
#' are wrappers around [move2utils::mt_dbbmm_variance()] and
#' [move2utils::mt_dbbmm_ud()] (or [move2utils::mt_dbgb_variance()] and
#' [move2utils::mt_dbgb_ud()]), which require the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' @details Bridges link consecutive events within a track, so the UD is
#' estimated for each track: `x` must be either ungrouped, or grouped by its
#' track id column only. `x` must be ordered by time within each track (see
#' [tt_order_time()]), and have a projected coordinate reference system in
#' metres (see [sf::st_transform()]), as the bridges are computed in metres.
#' Events with an empty geometry (i.e. no location) are ignored. Tracks with
#' fewer events than `window_size` are skipped by `move2utils` (with a
#' warning), and are not included in the output.
#'
#' **The grid.** The UDs of all tracks are estimated on a shared grid, which
#' must contain the whole of every bridge: bridges can extend well beyond the
#' locations (e.g. across long gaps between events, when the motion variance is
#' high). The motion variance is therefore estimated first, and used to compute
#' the extent of each bridge (up to five standard deviations from its mean
#' path). If `bbox` is `NULL` (the default), the grid covers the extent of all
#' the bridges, plus five cells on each side. If `bbox` is given and does not
#' contain all the bridges (with a margin of two cells), an error is given,
#' reporting the extent needed.
#'
#' The grid must also be fine relative to the width of the bridges, as the
#' densities are evaluated at the centres of the cells: bridges much narrower
#' than the cells (e.g. with frequent, accurate locations) can fall between
#' them, giving a patchy UD (or an error, if no density is left). If `res` is
#' `NULL` (the default), the cells are as wide as the median width of the
#' bridges (their standard deviation half way between consecutive events), but
#' no smaller than needed for the longest side of the grid (the extent of the
#' bridges, or `bbox` if given) to have 500 cells. A warning is given if the
#' cells are more than ten times wider than the median width of the bridges.
#'
#' Note that these defaults differ from the grid used by [hr_tt_kde()] (the
#' extent of the locations, expanded by 100% of the range on each side, with
#' about 1000 cells). To compare the UDs from different methods (e.g. with
#' [hr_tt_ud_overlap()]), estimate them on the same grid, e.g. by passing the
#' grid of the bridges (columns `xmin`, `ymin`, `xmax`, `ymax` and `res` of the
#' output) as `bbox` and `res` to [hr_tt_kde()].
#'
#' If `levels` is set, the isopleths for the specified levels are returned
#' instead of the full UDs, as in [hr_tt_kde()].
#'
#' @param x A `move2` object with a projected coordinate reference system in
#'   metres, either ungrouped or grouped by its track id column.
#' @param location_error The error of the locations (the standard deviation of
#'   the position). Either a `units` object (e.g. `as_units(20, "m")`) with one
#'   value for all events or one value per event, the name of a column of `x`
#'   with the errors (as a `units` object), or `NULL` (the default) to treat
#'   locations as exact. Missing values are replaced by the median error of
#'   their track, as in `move2utils`.
#' @param window_size The number of events in the sliding window used to
#'   estimate the motion variance (an odd number). It is a number of events
#'   rather than a duration: with an event every 2 minutes, a window of 15
#'   events covers 30 minutes.
#' @param margin The number of events at each end of the window that are not
#'   considered as breakpoints when looking for changes in the motion variance
#'   (an odd number).
#' @param bbox A named vector of four elements (`xmin`, `ymin`, `xmax`,
#'   `ymax`), in the coordinates of `x`, defining the grid shared by all
#'   tracks. If `NULL`, the grid covers all the bridges (see Details).
#' @param res The resolution of the grid, as a `units` object (e.g.
#'   `as_units(50, "m")`). If `NULL`, it is chosen from the width of the
#'   bridges (see Details).
#' @param time_step The time step used to integrate the bridges, as a `units`
#'   object (e.g. `as_units(10, "s")`). If `NULL`, the default of `move2utils`
#'   is used (a fraction of the shortest interval between events).
#' @param levels A vector of levels for the isopleths, as numbers between 0
#'   and 1. If `NULL` (the default), the full UDs are returned.
#' @param ... Further arguments passed to [move2utils::mt_dbbmm_variance()] or
#'   [move2utils::mt_dbgb_variance()] (e.g. `parallel` and `cores`).
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#'   `NULL`, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
#'   [hr_tt_ud_iso()]), with columns:
#' - the track id column of `x`: the ids of the tracks
#' - `method`: the method used to estimate the home range (`"dbbmm"` or
#'   `"dbgb"`)
#' - `window_size` and `margin`: the values used for the sliding window
#' - `xmin`, `ymin`, `xmax`, `ymax` and `res`: the extent and resolution of
#'   the grid (in metres)
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
#' # project the data to a projection in metres
#' x <- sf::st_transform(example_tt, "+proj=eqearth")
#' ud_dbbmm <- hr_tt_dbbmm(
#'   x,
#'   location_error = as_units(1000, "m"),
#'   window_size = 3,
#'   margin = 1
#' )
#' ud_dbbmm
#' # estimate kernel UDs on the same grid, to compare them
#' ud_kde <- hr_tt_kde(
#'   x,
#'   bbox = unlist(ud_dbbmm[1, c("xmin", "ymin", "xmax", "ymax")]),
#'   res = ud_dbbmm$res[1]
#' )
#' hr_tt_ud_overlap(ud_dbbmm$ud[[1]], ud_kde$ud[[1]])
hr_tt_dbbmm <- function(
  x,
  location_error = NULL,
  window_size = 31,
  margin = 11,
  bbox = NULL,
  res = NULL,
  time_step = NULL,
  levels = NULL,
  ...
) {
  # move2utils is only suggested (and not on CRAN), so check for it first,
  # with an error naming this function
  check_move2utils("hr_tt_dbbmm") # nolint: object_usage_linter.
  # the defaults of window_size and margin are those of mt_dbbmm_ud()
  hr_tt_bridge(
    x,
    method = "dbbmm",
    location_error = location_error,
    window_size = window_size,
    margin = margin,
    bbox = bbox,
    res = res,
    time_step = time_step,
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
  time_step = NULL,
  levels = NULL,
  ...
) {
  check_move2utils("hr_tt_dbgb") # nolint: object_usage_linter.
  # the defaults are those of mt_dbgb_ud() (with a wider margin than for
  # dBBMM)
  hr_tt_bridge(
    x,
    method = "dbgb",
    location_error = location_error,
    window_size = window_size,
    margin = margin,
    bbox = bbox,
    res = res,
    time_step = time_step,
    levels = levels,
    ...
  )
}

#' Estimate the UD of each track with a move2utils bridge model
#'
#' Shared by [hr_tt_dbbmm()] and [hr_tt_dbgb()].
#'
#' @param method Either "dbbmm" or "dbgb".
#' @inheritParams hr_tt_dbbmm
#' @returns See [hr_tt_dbbmm()].
#' @keywords internal
#' @noRd
hr_tt_bridge <- function(
  x,
  method,
  location_error,
  window_size,
  margin,
  bbox,
  res,
  time_step,
  levels,
  ...
) {
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  # the bridges are computed in metres; with any other crs, move2utils would
  # silently compute on a reprojected copy of our grid, so that the checks
  # below (which protect against out of bounds writes in its C code) would
  # no longer apply to the grid actually used
  if (
    sf::st_is_longlat(x) ||
      !identical(sf::st_crs(x)$units_gdal, "metre")
  ) {
    stop(
      "x must have a projected coordinate reference system in metres ",
      "(see sf::st_transform())"
    )
  }
  # bridges only make sense between consecutive events of the same track, so
  # any grouping other than by track would be silently ignored by move2utils
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
  # move2utils also checks the order, but per track and with a less helpful
  # message; we point to tt_order_time() instead of reordering silently
  check_time_ordered(x) # nolint: object_usage_linter.
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  # convert the units objects to the plain numbers move2utils expects (metres
  # for distances, minutes for time_step); this is done on the full x, as a
  # per-event location_error refers to all its events
  location_error <- bridge_location_error(x, location_error)
  # to_metres() also checks that res is a single positive distance
  if (!is.null(res)) {
    res <- to_metres(res, "res") # nolint: object_usage_linter.
  }
  if (!is.null(time_step)) {
    time_step <- bridge_time_step(time_step)
  }

  # move2utils gives an error for events with an empty geometry, whilst they
  # are allowed in tidytracks: they have no location to contribute to the UD,
  # so they are dropped (with their location errors, to keep them aligned)
  located <- !sf::st_is_empty(x)
  x <- x[located, ]
  location_error <- location_error[located]

  variance_fn <- switch(method,
    dbbmm = move2utils::mt_dbbmm_variance,
    dbgb = move2utils::mt_dbgb_variance
  )
  ud_fn <- switch(method,
    dbbmm = move2utils::mt_dbbmm_ud,
    dbgb = move2utils::mt_dbgb_ud
  )

  # one row per track, in the same order (and with the same character ids) as
  # hr_tt_kde() for ungrouped data, rather than the order in which the tracks
  # appear in x (used by move2utils)
  track_ids <- as.character(
    dplyr::group_keys(dplyr::group_by(x, .data[[track_col]]))[[1]]
  )

  # the motion variance is estimated first (rather than letting the ud
  # functions of move2utils do it), as it is needed to size the grid before
  # the C code runs
  variance <- variance_fn(
    x,
    location_error = location_error,
    window_size = window_size,
    margin = margin,
    ...
  )
  # with a single track, move2utils returns a variance object rather than a
  # list of them; a list is always used below, which also makes the ud
  # function name each layer after its track
  if (inherits(variance, c("mt_dbbmm_variance", "mt_dbgb_variance"))) {
    variance <- stats::setNames(list(variance), track_ids)
  }
  # move2utils skips tracks with fewer events than window_size (with a
  # warning), so they have no variance and are left out of the output; it
  # gives an error itself if no track is left
  track_ids <- intersect(track_ids, names(variance))
  variance <- variance[track_ids]

  # the extent and width of every bridge (segment between consecutive events)
  # of every track, as the tracks share one grid
  segments <- do.call(rbind, lapply(variance, bridge_segments))
  needed <- c(
    xmin = min(segments$xmin),
    ymin = min(segments$ymin),
    xmax = max(segments$xmax),
    ymax = max(segments$ymax)
  )
  # only the bridges drawn into the UD tell how fine the grid must be (the
  # others include those at the ends of the tracks, which have no motion
  # variance and would make the default cells too small)
  width <- stats::median(segments$width[segments$drawn])

  # the grid shared by all tracks
  if (!is.null(bbox)) {
    bbox <- normalise_kde_bbox(bbox) # nolint: object_usage_linter.
  }
  if (is.null(res)) {
    # cells as wide as a typical bridge, but no more than 500 cells along the
    # longest side of the grid, which bounds the time and memory needed (the
    # C code evaluates every cell within reach of each time step)
    span <- if (is.null(bbox)) needed else bbox
    longest_side <- max(
      span[["xmax"]] - span[["xmin"]],
      span[["ymax"]] - span[["ymin"]]
    )
    res <- max(width, longest_side / 500)
  }
  if (is.null(bbox)) {
    bbox <- needed + c(-5, -5, 5, 5) * res
  }
  # extend xmax and ymax to a whole number of cells, as in hr_tt_kde()
  bbox <- align_kde_bbox(bbox, res) # nolint: object_usage_linter.
  # the C code of move2utils has an off-by-one error in its bounds checks, so
  # a bridge reaching the outermost cell (or one cell beyond it) is written
  # outside the grid, corrupting memory instead of giving an error; the
  # bridges must therefore stay at least two cells within the grid, which
  # also guarantees a grid of at least four cells along each side (the C code
  # reads the resolution from the first two cell centres)
  inner <- bbox + c(2, 2, -2, -2) * res
  if (
    needed[["xmin"]] < inner[["xmin"]] || needed[["ymin"]] < inner[["ymin"]] ||
      needed[["xmax"]] > inner[["xmax"]] || needed[["ymax"]] > inner[["ymax"]]
  ) {
    stop(
      "the grid is not large enough to contain the bridges: bbox must ",
      "extend at least two cells beyond xmin = ", round(needed[["xmin"]]),
      ", ymin = ", round(needed[["ymin"]]), ", xmax = ",
      round(needed[["xmax"]]), ", ymax = ", round(needed[["ymax"]])
    )
  }
  # densities are evaluated at the cell centres only, so bridges narrower
  # than the cells can fall between them
  if (width > 0 && res > 10 * width) {
    warning(
      "the cells of the grid (", signif(res, 3), " m) are much wider than ",
      "the median width of the bridges (", signif(width, 3), " m), so the ",
      "UDs may be patchy; consider a smaller res"
    )
  }
  grid <- terra::rast(
    xmin = bbox[["xmin"]],
    xmax = bbox[["xmax"]],
    ymin = bbox[["ymin"]],
    ymax = bbox[["ymax"]],
    ncols = round((bbox[["xmax"]] - bbox[["xmin"]]) / res),
    nrows = round((bbox[["ymax"]] - bbox[["ymin"]]) / res),
    crs = sf::st_crs(x)$wkt
  )
  # move2utils reprojects the grid (invalidating the check above) if its crs
  # does not compare equal to the crs of the variance objects; this should
  # not happen for a projected crs in metres, but is checked before the C
  # code runs, as the consequence would be memory corruption
  if (sf::st_crs(terra::crs(grid)) != variance[[1]]$track_data$crs) {
    stop(
      "the crs of x could not be used for the grid of the bridges; ",
      "transform x to another projected crs in metres"
    )
  }

  # the location errors stored in the variance objects are used (the ud
  # functions do not accept per-event errors with a list of variances); the
  # grid has the crs of x, so move2utils returns the UDs on it unchanged
  uds <- tryCatch(
    ud_fn(variance, raster = grid, time_step = time_step, verbose = FALSE),
    error = function(e) {
      # the only way to get no density on a grid that contains all bridges
      if (grepl("zero or non-finite", conditionMessage(e))) {
        stop(
          "no density was left on the grid, as the bridges are too narrow ",
          "relative to its cells; use a smaller res",
          call. = FALSE
        )
      }
      stop(e)
    }
  )
  # one single-layer SpatRaster per track, with the layer named "ud" (as
  # expected by the hr_tt_ud_* functions) and the same metadata as the UDs
  # of hr_tt_kde()
  ud_list <- lapply(track_ids, function(id) {
    ud <- uds[[id]]
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
  # the first column is named after the track id column, so that functions
  # such as event_ud_level() can match the UDs to the events
  names(res_tbl)[1] <- track_col
  class(res_tbl) <- c("hr_tt_ud_tbl", class(res_tbl))

  if (!is.null(levels)) {
    res_tbl <- hr_tt_ud_iso(res_tbl, levels) # nolint: object_usage_linter.
  }
  res_tbl
}

#' Get the location error of each event, in metres
#'
#' @param x A `move2` object.
#' @param location_error `NULL`, a `units` object with one value or one value
#'   per event, or the name of a column of `x` (with a `units` object).
#' @returns A numeric vector of errors in metres, one per event of `x` (with
#'   the missing values left for `move2utils` to replace).
#' @keywords internal
#' @noRd
bridge_location_error <- function(x, location_error) {
  # exact locations: the bridges then pinch to a point at each event
  if (is.null(location_error)) {
    return(rep(0, nrow(x)))
  }
  if (is.character(location_error) && length(location_error) == 1) {
    location_error <- location_error_column( # nolint: object_usage_linter.
      x,
      location_error
    )
  }
  # plain numbers are rejected, as elsewhere in tidytracks
  if (
    !inherits(location_error, "units") ||
      !units::ud_are_convertible(units::deparse_unit(location_error), "m")
  ) {
    stop(
      "location_error must be a units object (e.g. as_units(20, 'm')), ",
      "or the name of a column of x"
    )
  }
  location_error <- as.numeric(
    units::set_units(location_error, "m", mode = "standard")
  )
  if (!length(location_error) %in% c(1, nrow(x))) {
    stop("location_error must have one value, or one value per event")
  }
  # always one value per event, so that it can be subset with the events
  location_error <- rep_len(location_error, nrow(x))
  if (all(is.na(location_error))) {
    stop("location_error must have at least one non-missing value")
  }
  # missing values are left to move2utils, which replaces them within each
  # track, from its located events (by their median, its default
  # location_error_na); the errors it uses are stored in the variance
  # objects, from which the grid is sized
  if (any(location_error < 0, na.rm = TRUE)) {
    stop("location_error must not be negative")
  }
  location_error
}

#' Convert the integration time step to minutes, as used by move2utils
#'
#' @param time_step A `units` object with time units.
#' @returns The time step in minutes.
#' @keywords internal
#' @noRd
bridge_time_step <- function(time_step) {
  # a plain number would be ambiguous (move2utils expects minutes here, but
  # seconds for some other times), so units are required
  if (
    !inherits(time_step, "units") || length(time_step) != 1 ||
      !units::ud_are_convertible(units::deparse_unit(time_step), "min")
  ) {
    stop(
      "time_step must be a units object with time units: ",
      "e.g. as_units(10, 's')"
    )
  }
  time_step <- as.numeric(units::set_units(time_step, "min", mode = "standard"))
  # a zero step would make the C code loop forever
  if (!is.finite(time_step) || time_step <= 0) {
    stop("time_step must be positive")
  }
  time_step
}

#' Compute the extent and width of the bridges of a track
#'
#' The C code of `move2utils` evaluates each bridge at a series of time steps,
#' within a number of standard deviations of its mean (4 for dBBMM, 5 for
#' dBGB). For the segment between events `k` and `k + 1`, separated by `dt`
#' minutes, the variance of the bridge at a fraction `a` of the segment is
#' `dt * a * (1 - a) * s + (1 - a)^2 * e_k^2 + a^2 * e_{k + 1}^2`, where `s`
#' is the motion variance (for dBGB, the larger of the parallel and orthogonal
#' variances) and `e` the location errors. Its maximum is at most
#' `dt * s / 4 + max(e_k, e_{k + 1})^2`, which gives a conservative extent for
#' each segment (using 5 standard deviations for both methods).
#'
#' @param variance The variance object of a track from `move2utils`.
#' @returns A data frame with one row per segment between consecutive events
#'   linked by a bridge, with columns `xmin`, `ymin`, `xmax` and `ymax` (the
#'   extent of the bridge), `width` (the standard deviation of the bridge half
#'   way between its events) and `drawn` (whether the bridge is drawn into the
#'   UD by `move2utils`).
#' @keywords internal
#' @noRd
bridge_segments <- function(variance) {
  # the coordinates, times (in minutes) and location errors stored in the
  # variance object are exactly those that the C code receives
  track <- variance$track_data
  xy <- cbind(track$x, track$y)
  time_mins <- track$time_mins
  # as in move2utils, variance objects without stored errors use exact
  # locations
  location_error <- if (is.null(track$location_error)) {
    rep(0, track$n_locs)
  } else {
    rep_len(track$location_error, track$n_locs)
  }
  # in units of variance (m^2 per minute) for both methods: move2utils
  # squares the standard deviations stored for dBGB
  motion_variance <- move2utils::mt_motion_variance(variance)
  if (inherits(variance, "mt_dbgb_variance")) {
    # the dBGB kernel is elongated along the direction of movement, but its
    # extent uses the larger of its two standard deviations
    motion_variance <- pmax(motion_variance$para, motion_variance$orth)
    # dBGB keeps only the events of interest (those with the most variance
    # estimates), and links each to the next one kept
    interest <- variance$seg_interest
    xy <- xy[interest, , drop = FALSE]
    time_mins <- time_mins[interest]
    location_error <- location_error[interest]
    motion_variance <- motion_variance[interest]
    drawn <- rep(TRUE, nrow(xy))
  } else {
    # dBBMM keeps all events, but only draws the bridges starting at an event
    # of interest; all bridges are still included in the extent, to be safe
    drawn <- variance$interest
  }
  if (length(motion_variance) != nrow(xy)) {
    stop("the motion variance does not match the events of the track")
  }
  # segment k links event k to event k + 1, and uses the motion variance of
  # event k
  k <- seq_len(nrow(xy) - 1)
  motion_variance <- motion_variance[k]
  # the C code also replaces missing variances (at the ends of the track,
  # where there are too few events for a window) by zero
  motion_variance[is.na(motion_variance)] <- 0
  # the movement part of the variance, which peaks half way (a = 1 / 2)
  bridge_var <- diff(time_mins) * motion_variance / 4
  # the mean of the bridge moves along the segment, so its extent is that of
  # the segment, widened by 5 sd of the largest possible variance
  half_width <- 5 * sqrt(
    bridge_var + pmax(location_error[k], location_error[k + 1])^2
  )
  data.frame(
    xmin = pmin(xy[k, 1], xy[k + 1, 1]) - half_width,
    ymin = pmin(xy[k, 2], xy[k + 1, 2]) - half_width,
    xmax = pmax(xy[k, 1], xy[k + 1, 1]) + half_width,
    ymax = pmax(xy[k, 2], xy[k + 1, 2]) + half_width,
    width = sqrt(
      bridge_var + (location_error[k]^2 + location_error[k + 1]^2) / 4
    ),
    drawn = drawn[k]
  )
}
