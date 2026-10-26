#' Quantify the home range using autocorrelated kernel density estimation
#'
#' This function estimates the home range of each track using autocorrelated
#' kernel density estimation (AKDE, Fleming et al. 2015), as implemented in
#' the package `ctmm` ([ctmm::akde()]). Unlike conventional kernel density
#' estimation ([hr_tt_kde()]), AKDE accounts for the autocorrelation of
#' locations in tracking data, which otherwise leads to underestimating home
#' ranges. AKDE requires a movement model for each track, which must first be
#' fitted with [ctmm_tt_fit()].
#'
#' @details The utilisation distributions (UDs) are estimated on a grid
#'   shared by all groups (unless a `bbox` is given for each group), so that
#'   they can be combined or compared (e.g. with [hr_tt_ud_sum()] or
#'   [hr_tt_ud_overlap()]). By default, the grid follows the defaults of
#'   [ctmm::akde()]: its resolution is a tenth of the smallest bandwidth (or
#'   of the smallest standard deviation of the home range of the movement
#'   model) among all groups, and it extends far enough from the locations to
#'   contain all but a fraction `tolerance` of each UD. The cells are square,
#'   so that the grid can be used with the other `hr_tt_` functions.
#'
#'   Each UD is estimated by `ctmm` directly on the grid (i.e. it is not
#'   resampled), and is standardised to sum to 1 over the grid. The `ctmm` UD
#'   objects are also returned (in column `ud_ctmm`), so that they can be used
#'   with other functions of `ctmm` (e.g. [ctmm::overlap()] or
#'   [ctmm::meta()]), and so that [hr_tt_ud_iso()] can compute the
#'   confidence intervals of the areas of the isopleths of the UDs (i.e.
#'   `hr_tt_ud_iso(hr_tt_akde(x, models), levels)` returns the same isopleths
#'   as `hr_tt_akde(x, models, levels = levels)`, without estimating the UDs
#'   again).
#'
#'   The models are matched to the tracks by track id. As models are fitted to
#'   each track, each group of `x` must contain a single track (which is the
#'   case when `x` is not grouped). The tracks must not have changed since the
#'   models were fitted (i.e. they must have the same events with a location).
#'   Models without a home range (e.g. Brownian motion) cannot be used.
#'
#' @references Fleming, C.H., Fagan, W.F., Mueller, T., Olson, K.A.,
#'   Leimgruber, P. & Calabrese, J.M. (2015) Rigorous home range estimation
#'   with movement data: a new autocorrelated kernel density estimator.
#'   Ecology, 96, 1182-1188.
#'
#'   Fleming, C.H., Sheldon, D., Fagan, W.F., Leimgruber, P., Mueller, T.,
#'   Nandintsetseg, D., Noonan, M.J., Olson, K.A., Setyawan, E., Sianipar, A.
#'   & Calabrese, J.M. (2018) Correcting for missing and irregular data in
#'   home-range estimation. Ecological Applications, 28, 1003-1010.
#' @param x A move2 object, in a projected coordinate reference system with
#'   units in metres (the same used to fit the models). If grouped, each group
#'   must contain a single track; otherwise, the track id is used as grouping
#'   variable.
#' @param models A table of movement models created with [ctmm_tt_fit()]
#'   (with a model for each track in `x`).
#' @param bbox A named vector of four elements (`xmin`, `ymin`, `xmax`,
#'   `ymax`) defining a grid shared by all groups, or a list of one such vector
#'   per group. If `NULL` (the default), a shared grid that contains all the
#'   UDs is created (see Details).
#' @param res The resolution of the grid (in metres). Supply one value for a
#'   shared resolution or one value per group. If `NULL` (the default), the
#'   resolution follows the default of `ctmm` (see Details); with a list of
#'   `bbox` (one per group), each group has its own default resolution.
#'
#'   Per-group values of `bbox` and `res` are matched to the groups in the
#'   order of [dplyr::group_keys()] (i.e. sorted by the grouping variables).
#' @param levels A vector of levels for the isopleths (i.e. contour lines), as
#'   numbers between 0 and 1. If `NULL` (the default), the full UD is
#'   returned; otherwise just the isopleths are returned (see [hr_tt_kde()]).
#' @param weights Logical; if `TRUE`, the locations are weighted to account
#'   for irregular sampling and gaps in the tracks (Fleming et al. 2018). This
#'   is recommended for irregularly sampled tracks, but it is slower. Default
#'   is `FALSE`.
#' @param debias Logical; whether to correct the bias of the estimate of the
#'   home range area (see [ctmm::akde()]). Default is `TRUE`.
#' @param tolerance The target error of the numerical computations of
#'   [ctmm::akde()] (its `error` argument), which also defines the default grid
#'   (the probability mass of each UD outside the grid). A warning is given
#'   if more than this (and more than 1%) of a UD is outside the grid (e.g.
#'   with a `bbox` that is too small). Default is 0.001.
#' @param ci_level The confidence level of the confidence intervals of the
#'   home range areas, returned when `levels` is set. Default is 0.95.
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#' NULL, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
#' [hr_tt_ud_iso()]), with columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`
#' - `method`: the method used to estimate the home range (`"akde"`)
#' - `model_name`: the name of the movement model used
#' - `dof_area`: the effective number of degrees of freedom of the home range
#'   area (small values imply very uncertain estimates)
#' - `xmin`, `ymin`, `xmax`, `ymax`: the bounding box of the grid
#' - `res`: the resolution of the grid
#' If `levels` is NULL:
#' - `ud`: the UDs, as a list-column of `terra::SpatRaster` objects
#' - `ud_ctmm`: the UDs, as a list-column of `ctmm` `UD` objects
#' Else, if `levels` is not NULL, there is one row per group and level, and
#' the following columns are added:
#' - `level`: the level of the isopleth
#' - `area`: the area of the isopleth (computed from its polygon)
#' - `area_low`, `area_high`: the confidence interval of the home range area
#'   at this level, as estimated by `ctmm` (its point estimate, computed from
#'   the UD rather than from the polygon, can differ slightly from `area`)
#' - `geometry`: an `sfc` column containing the multipolygons representing
#'   the isopleth for the appropriate level
#' @seealso [ctmm_tt_fit()] to fit the movement models, [hr_tt_akde_pop()]
#'   to combine the UDs into population UDs, [hr_tt_kde()] for conventional
#'   kernel density estimation.
#' @export
#' @examplesIf rlang::is_installed("ctmm")
#' data(buffalo, package = "ctmm")
#' buffalo_tt <- mt_as_move2(buffalo)
#' # we use a subset of the first two buffalo to make the example fast
#' buffalo_sub <- buffalo_tt %>%
#'   filter_by_meta(track %in% c("Cilla", "Gabs")) %>%
#'   dplyr::group_by(track) %>%
#'   dplyr::slice_head(n = 100) %>%
#'   dplyr::ungroup()
#' buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#' buffalo_akde <- hr_tt_akde(buffalo_sub, buffalo_fit)
#' buffalo_akde
#' library(ggplot2)
#' autoplot(buffalo_akde)
#' # the 50% and 95% isopleths, with confidence intervals on their area
#' hr_tt_akde(buffalo_sub, buffalo_fit, levels = c(0.5, 0.95))
hr_tt_akde <- function(
  x,
  models,
  bbox = NULL,
  res = NULL,
  levels = NULL,
  weights = FALSE,
  debias = TRUE,
  tolerance = 0.001,
  ci_level = 0.95
) {
  check_ctmm_installed()

  ## check the inputs
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  stopifnot_ctmm_tt_fit_tbl(models)
  # the models are matched to the tracks by track id
  id_col <- move2::mt_track_id_column(x)
  if (!identical(attr(models, "track_id_column"), id_col)) {
    stop(
      "the track id column of x ('", id_col, "') is not the one used to ",
      "fit the models ('", attr(models, "track_id_column"), "')"
    )
  }
  # the models are in the coordinates of the data they were fitted to
  if (sf::st_crs(x) != attr(models, "crs")) {
    stop(
      "x must have the same coordinate reference system used to fit the ",
      "models"
    )
  }
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  check_probability_arg(tolerance, "tolerance")
  # ci_level is only used for the isopleths (by hr_tt_ud_iso(), which also
  # checks it), but we check it now rather than after estimating all the UDs
  if (!is.null(levels)) {
    check_probability_arg(ci_level, "ci_level")
  }

  ## the groups, and the track of each group
  # if x is not grouped, use the track id column as grouping variable
  if (!inherits(x, "grouped_df")) {
    x <- dplyr::group_by(x, .data[[id_col]])
  }
  # per-group values (bbox and res) are matched to the groups by their
  # position in the group keys, so no group can be empty
  check_no_empty_groups(x) # nolint: object_usage_linter.
  n_groups <- dplyr::n_groups(x)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  # the models are fitted to each track, so each group must be a single track
  group_tracks <- akde_group_tracks(x)

  ## the model and the locations of each group
  fits <- akde_group_models(models, group_tracks)
  # convert the tracks to telemetry objects, with the same error columns used
  # to fit the models (needed by the error model, if one was fitted); the
  # messages of ctmm on the sampling intervals were already given when
  # fitting the models
  tel_list <- suppressMessages(mt_as_telemetry(
    dplyr::ungroup(x),
    error_cols = attr(models, "error_cols")
  ))
  # tracks without any location have no telemetry object
  if (!all(group_tracks %in% names(tel_list))) {
    stop("each group must contain at least one event with a location")
  }
  tel_list <- tel_list[group_tracks]
  # a model only applies to the locations it was fitted to
  check_akde_tracks_unchanged(models, tel_list, group_tracks)

  ## the grid of each group
  grids <- akde_group_grids(tel_list, fits, bbox, res, tolerance, group_labels)

  ## estimate the UD of each group, and store it in a row of the results
  crs <- sf::st_crs(x)
  akde_results <- lapply(seq_len(n_groups), function(i) {
    grid_bbox <- grids$bbox[[i]]
    grid_res <- grids$res[i]
    # ctmm evaluates the UD at the centres of the cells of our grid (rather
    # than on a grid of its own), so that the UD can be turned into a raster
    # without resampling
    ud_ctmm <- with_label_warnings(
      ctmm::akde(
        tel_list[[i]],
        fits[[i]],
        debias = debias,
        weights = weights,
        error = tolerance,
        grid = akde_grid(grid_bbox, grid_res),
        # with weights, ctmm plots the sampling intervals by default
        dt.plot = FALSE
      ),
      label = paste("group", group_labels[i])
    )
    # with too few degrees of freedom, ctmm returns the model instead of a UD
    if (!inherits(ud_ctmm, "UD")) {
      stop(
        "the home range could not be estimated for group ", group_labels[i],
        ", as its model has too few degrees of freedom for the area"
      )
    }
    model_name <- summary(fits[[i]])$name
    # the UD as a raster that sums to 1, as used by the other hr_tt_ functions
    ud <- ctmm_ud_to_rast(
      ud_ctmm,
      bbox = grid_bbox,
      crs = crs,
      id = group_labels[i],
      model_name = model_name,
      tolerance = tolerance
    )
    group_row <- tibble::tibble(
      group_id = group_labels[i],
      method = "akde",
      model_name = model_name,
      dof_area = summary(ud_ctmm, units = FALSE)$DOF[["area"]],
      xmin = grid_bbox[["xmin"]],
      ymin = grid_bbox[["ymin"]],
      xmax = grid_bbox[["xmax"]],
      ymax = grid_bbox[["ymax"]],
      res = grid_res
    )
    # the ctmm UD object is kept next to the raster, for the functions of
    # ctmm and for the confidence intervals of the areas of the isopleths
    group_row$ud <- list(ud)
    group_row$ud_ctmm <- list(ud_ctmm)
    names(group_row$ud) <- names(group_row$ud_ctmm) <- group_labels[i]
    group_row
  })
  akde_results <- do.call(rbind, akde_results)

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    akde_results <- akde_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x),
        dplyr::all_of("group_id")
      )
  }
  class(akde_results) <- c("hr_tt_ud_tbl", class(akde_results))

  # the isopleths are computed from the table of UDs, so that they are the
  # same as those returned by hr_tt_ud_iso() for the UDs (which also adds the
  # confidence intervals of their areas)
  if (!is.null(levels)) {
    akde_results <- hr_tt_ud_iso(akde_results, levels, ci_level = ci_level)
  }
  akde_results
}

#' Get the track of each group for AKDE
#'
#' The models are fitted to each track, so each group must contain a single
#' track, and each track must be in a single group.
#'
#' @param x A grouped `move2` object.
#' @returns A character vector with the track id of each group (in the order
#'   of [dplyr::group_keys()]).
#' @keywords internal
#' @noRd
akde_group_tracks <- function(x) {
  track_ids <- as.character(event_track_id(x))
  group_index <- dplyr::group_indices(x)
  group_tracks <- lapply(
    seq_len(dplyr::n_groups(x)),
    function(i) unique(track_ids[group_index == i])
  )
  if (any(lengths(group_tracks) != 1)) {
    stop(
      "each group of x must contain a single track, as the models are ",
      "fitted to each track (estimating a single home range from several ",
      "tracks is not supported yet)"
    )
  }
  group_tracks <- unlist(group_tracks)
  if (anyDuplicated(group_tracks)) {
    stop(
      "each track must be in a single group, as the models are fitted to ",
      "each track; to estimate home ranges for parts of the tracks (e.g. ",
      "trips or seasons), make them the tracks of x first (e.g. with ",
      "`tt_split_trips()` or `move2::mt_set_track_id()`), and fit their ",
      "models with `ctmm_tt_fit()`"
    )
  }
  group_tracks
}

#' Get the model of each group for AKDE
#'
#' @param models A table of models created with [ctmm_tt_fit()].
#' @param group_tracks The track id of each group.
#' @returns A list of `ctmm` models, one per group.
#' @keywords internal
#' @noRd
akde_group_models <- function(models, group_tracks) {
  model_ids <- as.character(models[[attr(models, "track_id_column")]])
  missing_tracks <- setdiff(group_tracks, model_ids)
  if (length(missing_tracks) > 0) {
    stop(
      "models has no model for track(s) ",
      paste(missing_tracks, collapse = ", ")
    )
  }
  fits <- models$model[match(group_tracks, model_ids)]
  # ctmm_tt_fit() stores NULL for the models that could not be fitted
  no_fit <- vapply(fits, is.null, logical(1))
  if (any(no_fit)) {
    stop(
      "the model could not be fitted for track(s) ",
      paste(group_tracks[no_fit], collapse = ", "),
      " (see column `fit_message` of models)"
    )
  }
  # models without a home range (e.g. Brownian motion) have range = FALSE
  no_range <- vapply(fits, function(fit) isFALSE(fit$range), logical(1))
  if (any(no_range)) {
    stop(
      "the model of track(s) ",
      paste(group_tracks[no_range], collapse = ", "),
      " has no home range (e.g. Brownian motion), so it cannot be used to ",
      "estimate a home range"
    )
  }
  unname(fits)
}

#' Check that the tracks have not changed since the models were fitted
#'
#' @param models A table of models created with [ctmm_tt_fit()].
#' @param tel_list A list of `telemetry` objects, one per group.
#' @param group_tracks The track id of each group.
#' @returns `NULL`, invisibly, if the number of events and the time range of
#'   each track are the same as when the models were fitted.
#' @keywords internal
#' @noRd
check_akde_tracks_unchanged <- function(models, tel_list, group_tracks) {
  # ctmm_tt_fit() stores the number of events and the time range of each
  # track (its "fingerprint") next to its model; we compare them with those
  # of the tracks now
  model_ids <- as.character(models[[attr(models, "track_id_column")]])
  fitted <- models[match(group_tracks, model_ids), , drop = FALSE]
  current <- ctmm_track_fingerprint(tel_list, group_tracks)
  # the times (in seconds) are compared with a small tolerance, to allow for
  # rounding errors
  changed <- fitted$n_events != current$n_events |
    abs(as.numeric(fitted$t_start) - as.numeric(current$t_start)) > 1e-6 |
    abs(as.numeric(fitted$t_end) - as.numeric(current$t_end)) > 1e-6
  if (any(changed)) {
    stop(
      "track(s) ",
      paste(group_tracks[changed], collapse = ", "),
      " have changed since the models were fitted (different number of ",
      "events with a location, or different time range); fit the models ",
      "again with `ctmm_tt_fit()`"
    )
  }
  invisible(NULL)
}

#' Set up the grid of each group for AKDE
#'
#' The `bbox` and `res` given by the user are checked and recycled to one per
#' group; when they are `NULL`, they follow the defaults of [ctmm::akde()]
#' (see Details of [hr_tt_akde()]), except that the cells are square.
#'
#' @param tel_list A list of `telemetry` objects, one per group.
#' @param fits A list of fitted `ctmm` models, one per group.
#' @param bbox,res The `bbox` and `res` arguments of [hr_tt_akde()].
#' @param tolerance The target error of the computations.
#' @param group_labels The labels of the groups (used in warnings).
#' @returns A list with elements `bbox` (a list with one named vector per
#'   group, extended to contain a whole number of cells) and `res` (a vector
#'   with one resolution per group).
#' @keywords internal
#' @noRd
akde_group_grids <- function(
  tel_list,
  fits,
  bbox,
  res,
  tolerance,
  group_labels
) {
  n_groups <- length(tel_list)
  # the default grid depends on the bandwidth of the kernel of each group;
  # we compute it without weights, which is quick (so with weights = TRUE,
  # the default grid can differ slightly from that of ctmm)
  if (is.null(bbox) || is.null(res)) {
    bandwidths <- lapply(seq_len(n_groups), function(i) {
      with_label_warnings(
        akde_bandwidth(tel_list[[i]], fits[[i]]),
        label = paste("group", group_labels[i])
      )
    })
  }

  ## the resolution of each group
  if (is.null(res)) {
    # as in ctmm, a tenth of the standard deviation of the kernel or of the
    # movement model, whichever is smaller; ctmm uses a different resolution
    # along each axis, whereas we use the smaller of the two, to get square
    # cells (the diagonals of the bandwidth and of sigma are variances)
    group_res <- vapply(
      seq_len(n_groups),
      function(i) {
        min(sqrt(pmin(diag(bandwidths[[i]]), diag(fits[[i]]$sigma)))) / 10
      },
      numeric(1)
    )
    # with a bbox for each group, each group has its own resolution; a grid
    # shared by all groups uses the finest of their resolutions (as ctmm does
    # when estimating several UDs on the same grid)
    per_group_bbox <- !is.null(bbox) && !is_kde_bbox(bbox)
    res <- if (per_group_bbox) group_res else rep(min(group_res), n_groups)
  } else if (!is.numeric(res) || !(length(res) %in% c(1, n_groups))) {
    stop(
      "res must be a single numeric value or a vector with one value per group"
    )
  }
  if (length(res) == 1) {
    res <- rep(res, n_groups)
  }
  if (any(!is.finite(res) | res <= 0)) {
    stop("res must contain finite, positive values")
  }

  ## the bounding box of each group
  if (is.null(bbox)) {
    # a grid shared by all groups, containing the default grid of each group
    # plus a buffer of one cell on each side (as in ctmm)
    default_bboxes <- lapply(seq_len(n_groups), function(i) {
      akde_default_bbox(tel_list[[i]], fits[[i]], bandwidths[[i]], tolerance)
    })
    # (the buffer moves xmin and ymin down, and xmax and ymax up)
    buffer <- max(res)
    shared_bbox <- bbox_union(default_bboxes) + # nolint: object_usage_linter.
      c(-buffer, -buffer, buffer, buffer)
    bbox <- rep(list(shared_bbox), n_groups)
  } else if (is_kde_bbox(bbox)) {
    # a single bbox, shared by all groups
    bbox <- rep(list(normalise_kde_bbox(bbox)), n_groups)
  } else {
    # one bbox per group
    if (!is.list(bbox) || length(bbox) != n_groups) {
      stop(
        "bbox must be a named vector of length 4 or a list with one ",
        "named vector per group"
      )
    }
    bbox <- lapply(bbox, normalise_kde_bbox)
  }
  # extend the bounding boxes to contain a whole number of cells
  bbox <- Map(align_kde_bbox, bbox, res)

  # warn about very large grids, which are slow and use a lot of memory
  n_cells <- mapply(
    function(b, r) {
      ((b[["xmax"]] - b[["xmin"]]) / r) * ((b[["ymax"]] - b[["ymin"]]) / r)
    },
    bbox,
    res
  )
  if (any(n_cells > 1e7)) {
    warning(
      "the grid has ", format(max(n_cells), big.mark = ","), " cells, ",
      "which can be slow and use a lot of memory; consider using a coarser ",
      "res, or a bbox for each group",
      call. = FALSE
    )
  }
  list(bbox = bbox, res = res)
}

#' Compute the bandwidth of the AKDE of a track
#'
#' This is only used to define the default grid ([ctmm::akde()] computes the
#' bandwidth again when estimating the UD). As in [ctmm::akde()], if the model
#' includes location error, the locations are first smoothed with the model.
#'
#' @param tel A `telemetry` object.
#' @param fit The fitted `ctmm` model.
#' @returns The bandwidth matrix (2x2), i.e. the covariance of the Gaussian
#'   kernel.
#' @keywords internal
#' @noRd
akde_bandwidth <- function(tel, fit) {
  if (any(fit$error > 0)) {
    tel <- stats::predict(fit, data = tel, t = tel$t)
    fit$error <- FALSE
  }
  # ctmm gives the same messages when estimating the UD with akde(), so we
  # silence them here
  suppressMessages(ctmm::bandwidth(tel, fit, dt.plot = FALSE))
}

#' Default bounding box of the AKDE of a track
#'
#' As in [ctmm::akde()], the grid extends beyond the locations by the
#' quantile of the kernel corresponding to `tolerance`, and contains the
#' 95% home range of the model (with its upper confidence limit at level
#' `1 - tolerance`).
#'
#' @param tel A `telemetry` object.
#' @param fit The fitted `ctmm` model.
#' @param bandwidth The bandwidth matrix.
#' @param tolerance The target error of the computations.
#' @returns A named vector with `xmin`, `ymin`, `xmax` and `ymax`.
#' @keywords internal
#' @noRd
akde_default_bbox <- function(tel, fit, bandwidth, tolerance) {
  # the radius (in standard deviations) of the circle containing
  # 1 - tolerance of the mass of a bivariate Gaussian kernel
  kernel_sd <- sqrt(diag(bandwidth))
  z <- sqrt(-2 * log(tolerance))
  # the extent of the home range of the model
  model_ext <- ctmm::extent(fit, level = 1 - tolerance)
  c(
    xmin = min(tel$x - z * kernel_sd[1], model_ext["min", "x"]),
    ymin = min(tel$y - z * kernel_sd[2], model_ext["min", "y"]),
    xmax = max(tel$x + z * kernel_sd[1], model_ext["max", "x"]),
    ymax = max(tel$y + z * kernel_sd[2], model_ext["max", "y"])
  )
}

#' Define a ctmm grid from a bounding box and a resolution
#'
#' When given the coordinates of the grid points, [ctmm::akde()] (and
#' [ctmm::pkde()]) evaluate the UD at those points rather than choosing a grid
#' of their own.
#'
#' @param bbox A named vector with `xmin`, `ymin`, `xmax` and `ymax` (aligned
#'   to the resolution).
#' @param res The resolution of the grid.
#' @returns A list with the coordinates of the centres of the cells along
#'   each axis (`r`) and the resolution (`dr`), as used by [ctmm::akde()].
#' @keywords internal
#' @noRd
akde_grid <- function(bbox, res) {
  n_x <- round((bbox[["xmax"]] - bbox[["xmin"]]) / res)
  n_y <- round((bbox[["ymax"]] - bbox[["ymin"]]) / res)
  list(
    r = list(
      x = bbox[["xmin"]] + res * (seq_len(n_x) - 0.5),
      y = bbox[["ymin"]] + res * (seq_len(n_y) - 0.5)
    ),
    dr = c(x = res, y = res)
  )
}

#' Convert a ctmm UD into a SpatRaster
#'
#' @param ud A `ctmm` `UD` object, estimated on the grid defined by `bbox`.
#' @param bbox The bounding box of the grid.
#' @param crs The coordinate reference system (an `sf` `crs` object).
#' @param id The identifier for the group (used in raster metadata).
#' @param model_name The name of the movement model (used in raster
#'   metadata).
#' @param method The method used to estimate the UD (used in raster
#'   metadata).
#' @param tolerance The probability mass of the UD that can be outside the
#'   grid (the `tolerance` of [hr_tt_akde()], which the default grid aims
#'   for): a warning is given if more than this, or more than 1%, is outside.
#' @returns A `terra::SpatRaster` with a layer `ud` that sums to 1.
#' @keywords internal
#' @noRd
ctmm_ud_to_rast <- function(
  ud,
  bbox,
  crs,
  id,
  model_name,
  method = "akde",
  tolerance = 0.001
) {
  # a ctmm UD is a list which stores the probability density at the points of
  # the grid (the centres of the cells) in `PDF`, a matrix with rows along x
  # and columns along y, and the resolution of the grid in `dr`; the
  # probability mass of a cell is its density times its area
  pmf <- ud$PDF * prod(ud$dr)
  # check that ctmm used the grid we requested, which defines the extent of
  # the raster
  res <- ud$dr[[1]]
  expected_dim <- round(c(
    (bbox[["xmax"]] - bbox[["xmin"]]) / res,
    (bbox[["ymax"]] - bbox[["ymin"]]) / res
  ))
  if (!all(dim(pmf) == expected_dim)) {
    stop("the UD estimated by ctmm is not on the requested grid")
  }
  # the probability mass within the grid, which is less than 1 by the mass
  # of the UD that falls outside the grid (at most about `tolerance` with the
  # default grid, but possibly more with a grid given by the user); we warn
  # only if more is outside than the tolerance allows (and at least 1%, so
  # that tiny losses with a small tolerance do not give warnings)
  sum_density <- sum(pmf, na.rm = TRUE)
  if (sum_density < 1 - max(0.01, tolerance)) {
    warning(
      "the grid of group ", id, " only contains ",
      round(100 * sum_density, 1), "% of the utilisation distribution; ",
      "consider a larger bbox",
      call. = FALSE
    )
  }
  # standardise the UD to sum to 1 over the grid, as for the UDs of
  # hr_tt_kde() (the other hr_tt_ functions, e.g. to compute the isopleths,
  # rely on it)
  pmf <- pmf / sum_density
  # in a raster, rows are along y (from north to south) and columns along x,
  # so we transpose the matrix and reverse the order of its rows
  pmf <- t(pmf)
  pmf <- pmf[rev(seq_len(nrow(pmf))), , drop = FALSE]
  r <- terra::rast(
    pmf,
    crs = crs$wkt,
    extent = terra::ext(
      bbox[["xmin"]],
      bbox[["xmax"]],
      bbox[["ymin"]],
      bbox[["ymax"]]
    )
  )
  names(r) <- "ud"
  terra::metags(r) <- c(
    paste0("id = ", id),
    paste0("method = ", method),
    paste0("model = ", model_name),
    paste0("density_sum = ", sum_density)
  )
  r
}

#' Add the confidence intervals of the areas to the isopleths of an AKDE
#'
#' @param iso An `sf` object with the isopleths of a UD (as returned by
#'   [hr_tt_ud_iso()] for a `SpatRaster`).
#' @param ud_ctmm The `ctmm` `UD` object of the same UD.
#' @param ci_level The confidence level of the intervals of the areas.
#' @returns `iso`, with the columns `area_low` and `area_high` added after
#'   `area`.
#' @keywords internal
#' @noRd
akde_iso_area_ci <- function(iso, ud_ctmm, ci_level) {
  # for each level of the isopleths (level.UD in ctmm), ctmm estimates the
  # area of the home range with its confidence interval (a table with one
  # row and columns low, est and high); with units = FALSE, the areas are in
  # square metres
  area_ci <- lapply(iso$level, function(level) {
    summary(ud_ctmm, level.UD = level, level = ci_level, units = FALSE)$CI
  })
  area_low <- vapply(area_ci, function(ci) ci[1, "low"], numeric(1))
  area_high <- vapply(area_ci, function(ci) ci[1, "high"], numeric(1))
  iso$area_low <- units::as_units(area_low, "m^2")
  iso$area_high <- units::as_units(area_high, "m^2")
  dplyr::relocate(
    iso,
    dplyr::all_of(c("area_low", "area_high")),
    .after = "area"
  )
}

#' Check that an argument is a single number between 0 and 1 (excluded)
#'
#' @param value The value of the argument.
#' @param name The name of the argument (used in the error message).
#' @returns `NULL`, invisibly, if `value` is valid.
#' @keywords internal
#' @noRd
check_probability_arg <- function(value, name) {
  if (
    !is.numeric(value) ||
      length(value) != 1 ||
      !is.finite(value) ||
      value <= 0 ||
      value >= 1
  ) {
    stop(name, " must be a single number between 0 and 1", call. = FALSE)
  }
  invisible(NULL)
}
