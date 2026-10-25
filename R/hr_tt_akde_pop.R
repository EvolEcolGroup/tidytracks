#' Combine AKDE home ranges into population home ranges
#'
#' This function combines the utilisation distributions (UDs) of individual
#' tracks estimated with [hr_tt_akde()] into population-level UDs, using the
#' methods of the package `ctmm`. If `x` is grouped (e.g. by a variable of the
#' metadata, such as sex or colony, joined to the table of UDs), a population
#' UD is estimated for each group; otherwise, all the UDs are combined into a
#' single population UD.
#'
#' @details Two methods are available:
#'   - `"pkde"` (the default): population kernel density estimation
#'   ([ctmm::pkde()]), which estimates the population UD from the locations
#'   of all the tracks of a group, using kernels based on the movement models
#'   of the individuals. This requires the tracks (`tracks`) and the models
#'   (`models`) used to estimate the individual UDs.
#'   - `"mean"`: the (weighted) average of the individual UDs
#'   (`ctmm::mean.UD()`). The UD is the same as the one obtained with
#'   [hr_tt_ud_sum()], but the `ctmm` UD object includes a population model,
#'   which is used to estimate the confidence intervals of the population home
#'   range area. With `sample = TRUE` (the default), the tracks are considered
#'   a sample of a larger population, and the uncertainty of the population
#'   distribution is taken into account.
#'
#'   In both cases, the uncertainty of the population home range areas
#'   reflects the variation among individuals, and it is large for groups
#'   with few individuals (as shown by small values of `dof_area`).
#'
#'   `ctmm` estimates some of the population-level parameters (e.g. the
#'   bandwidth of the population kernels with `method = "pkde"`) with a
#'   stochastic optimiser, so the results can differ between runs. With
#'   `method = "pkde"`, both the population UD and the confidence intervals of
#'   its area can differ; with `method = "mean"`, the population UD is always
#'   the same, but the confidence intervals of its area (and `dof_area`) can
#'   differ. Set the seed of the random number generator (with [set.seed()])
#'   before calling `hr_tt_akde_pop()` to get reproducible results.
#'
#'   Population kernel density estimation assumes that the individuals of a
#'   group are a sample from a single population, whose home ranges are
#'   distributed around a common centre (following a Gaussian distribution).
#'   Groups of individuals in distinct areas (e.g. different colonies) should
#'   be estimated separately (e.g. by grouping `x` by colony): pooling them
#'   leads to a very smooth population UD, which can miss the areas used by
#'   a minority of individuals.
#'
#'   All the UDs of a group must be estimated on the same grid (as is the case
#'   for the UDs returned by a single call of [hr_tt_akde()] without a `bbox`
#'   for each group), and the population UD is estimated on that grid. With
#'   `method = "pkde"`, the kernels of the population are wider than those of
#'   the individuals, so the population UD can extend beyond the grid of the
#'   individual UDs; in this case, the grid is extended (by whole cells, so
#'   that it stays aligned with the original grid, and in the same way for all
#'   groups that shared it) to contain the population UD.
#'
#' @param x A tibble of UDs estimated with [hr_tt_akde()] (with the `ctmm` UD
#'   objects in column `ud_ctmm`), possibly grouped (e.g. with
#'   [dplyr::group_by()]) to estimate a population UD for each group. Each
#'   group must contain at least two UDs.
#' @param method The method used to combine the UDs, either `"pkde"` (the
#'   default) or `"mean"` (see Details).
#' @param tracks The `move2` object used to estimate the UDs with
#'   [hr_tt_akde()] (only needed with `method = "pkde"`).
#' @param models The table of models used to estimate the UDs, as created
#'   with [ctmm_tt_fit()] (only needed with `method = "pkde"`).
#' @param weights The weights of the individuals in the population UD. Either
#'   `NULL` (the default) for equal weights, the name of a numeric column of
#'   `x` with the relative weight of each UD, or, with `method = "pkde"`,
#'   `TRUE` to optimise the weights (see [ctmm::pkde()]; this requires the
#'   package `quadprog`).
#' @param sample Logical; with `method = "mean"`, whether the tracks are a
#'   sample of a larger population (`TRUE`, the default) or the whole
#'   population (`FALSE`).
#' @param levels A vector of levels for the isopleths (i.e. contour lines), as
#'   numbers between 0 and 1. If `NULL` (the default), the full population UDs
#'   are returned; otherwise just the isopleths are returned, with the
#'   confidence intervals of their areas (as for [hr_tt_akde()]).
#' @param ci_level The confidence level of the confidence intervals of the
#'   home range areas, returned when `levels` is set. Default is 0.95.
#' @param tolerance With `method = "pkde"`, the target error of the numerical
#'   computations of [ctmm::pkde()] (its `error` argument), which is also the
#'   largest probability mass of the population UD allowed outside the grid
#'   before the grid is extended. Default is 0.001.
#' @param ... Additional arguments passed to [ctmm::pkde()] (e.g. `kernel`).
#' @returns Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
#' NULL, an `sf` tibble of class `hr_tt_poly_tbl`, with one row per group (and
#' level), and columns:
#' - the grouping variables of `x` (if `x` is grouped)
#' - `method`: the method used to estimate the population UD (`"pkde"` or
#'   `"akde_mean"`)
#' - `n_ud`: the number of individual UDs combined
#' - `dof_area`: the effective number of degrees of freedom of the population
#'   home range area
#' - `xmin`, `ymin`, `xmax`, `ymax`, `res`: the grid of the population UD
#'   (the grid of the individual UDs, possibly extended, see Details)
#' If `levels` is NULL:
#' - `ud`: the population UDs, as a list-column of `terra::SpatRaster` objects
#' - `ud_ctmm`: the population UDs, as a list-column of `ctmm` `UD` objects
#' Else, if `levels` is not NULL:
#' - `level`, `area`, `area_low`, `area_high` and `geometry`, as returned by
#'   [hr_tt_akde()]
#' @seealso [hr_tt_akde()] to estimate the individual UDs, [hr_tt_ud_sum()]
#'   to combine UDs from any method (without confidence intervals).
#' @export
#' @examplesIf rlang::is_installed("ctmm")
#' data(buffalo, package = "ctmm")
#' buffalo_tt <- mt_as_move2(buffalo)
#' # we use a subset of three buffalo to make the example fast
#' buffalo_sub <- buffalo_tt %>%
#'   filter_by_meta(track %in% c("Cilla", "Gabs", "Mvubu")) %>%
#'   dplyr::group_by(track) %>%
#'   dplyr::slice_head(n = 100) %>%
#'   dplyr::ungroup()
#' buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#' buffalo_akde <- hr_tt_akde(buffalo_sub, buffalo_fit)
#' # population UD with population kernel density estimation (setting the seed
#' # for reproducible results, see Details)
#' set.seed(1)
#' buffalo_pop <- hr_tt_akde_pop(
#'   buffalo_akde,
#'   tracks = buffalo_sub,
#'   models = buffalo_fit
#' )
#' buffalo_pop
#' # or as the average of the individual UDs, with the 95% home range
#' hr_tt_akde_pop(buffalo_akde, method = "mean", levels = 0.95)
hr_tt_akde_pop <- function(
  x,
  method = c("pkde", "mean"),
  tracks = NULL,
  models = NULL,
  weights = NULL,
  sample = TRUE,
  levels = NULL,
  ci_level = 0.95,
  tolerance = 0.001,
  ...
) {
  check_ctmm_installed()
  method <- match.arg(method)
  stopifnot_akde_ud_table(x)
  # check the other arguments
  if (!is.null(levels) && (any(levels < 0 | levels > 1))) {
    stop("levels must be between 0 and 1")
  }
  if (!is.logical(sample) || length(sample) != 1 || is.na(sample)) {
    stop("sample must be TRUE or FALSE")
  }
  if (
    !is.numeric(tolerance) ||
      length(tolerance) != 1 ||
      tolerance <= 0 ||
      tolerance >= 1
  ) {
    stop("tolerance must be a single number between 0 and 1")
  }
  # work with a plain list of rasters (in case the UDs were wrapped)
  x <- unwrap_ud_column(x) # nolint: object_usage_linter.

  ## set up the groups
  # the rows of each group (a single group with all rows if x is not grouped)
  if (inherits(x, "grouped_df")) {
    keys <- dplyr::group_keys(x)
    rows_list <- dplyr::group_rows(x)
    group_labels <- tidyr::unite(keys, col = "group_labels") %>%
      dplyr::pull(1)
  } else {
    keys <- NULL
    rows_list <- list(seq_len(nrow(x)))
    group_labels <- "population"
  }
  n_groups <- length(rows_list)
  # a population UD needs at least two individual UDs
  too_small <- lengths(rows_list) < 2
  if (any(too_small)) {
    stop(
      "each group must contain at least two UDs to estimate a population UD ",
      "(group(s) ", paste(group_labels[too_small], collapse = ", "), ")"
    )
  }

  ## gather the inputs of each group
  # the individual UDs, whose ctmm objects include the movement models
  group_uds <- lapply(rows_list, function(rows) unname(x$ud_ctmm[rows]))
  # the weights of the UDs, in the form expected by ctmm (FALSE or NULL for
  # equal weights, TRUE for optimised weights, or one weight per UD)
  ud_weights <- akde_pop_weights(x, weights, method)
  group_weights <- lapply(rows_list, function(rows) {
    if (is.numeric(ud_weights)) ud_weights[rows] else ud_weights
  })
  # pkde estimates the population UD from the locations of the tracks, so it
  # also needs the telemetry object of the track of each UD
  if (method == "pkde") {
    ud_tels <- akde_pop_telemetry(tracks, models, x$ud_ctmm)
    group_tels <- lapply(rows_list, function(rows) ud_tels[rows])
  }
  # the grid of each group (its bounding box and resolution), on which the
  # population UD is estimated: all the UDs of a group must share it
  grid_tbl <- tibble::as_tibble(x)[, c("xmin", "ymin", "xmax", "ymax", "res")]
  group_grids <- lapply(seq_len(n_groups), function(i) {
    grid <- dplyr::distinct(grid_tbl[rows_list[[i]], ])
    if (nrow(grid) != 1) {
      stop(
        "all the UDs of group ", group_labels[i], " must be on the same grid ",
        "(e.g. estimated by hr_tt_akde() without a bbox for each group)"
      )
    }
    list(
      bbox = unlist(grid[1, c("xmin", "ymin", "xmax", "ymax")]),
      res = grid$res
    )
  })

  ## estimate the population UD of each group
  # estimate the population UD of group i on the grid with bounding box bbox
  estimate_pop_ud <- function(i, bbox) {
    pop_ud <- with_label_warnings(
      if (method == "pkde") {
        # population kernel density estimate from the locations of the
        # tracks, with kernels based on the movement models of the UDs; the
        # grid is given as the centres of its cells, which ctmm uses as they
        # are (without extending them to contain the UD)
        ctmm::pkde(
          group_tels[[i]],
          group_uds[[i]],
          weights = group_weights[[i]],
          error = tolerance,
          grid = akde_grid(bbox, group_grids[[i]]$res),
          trace = FALSE,
          ...
        )
      } else {
        # (weighted) average of the UDs, on their shared grid, with a
        # population model for the uncertainty of the area; mean() prints
        # the model selection of the population model, which we capture to
        # avoid cluttering the console (capture.output() returns the
        # printed text, so the UD is assigned within it)
        mean_ud <- NULL
        utils::capture.output(
          mean_ud <- suppressMessages(
            mean(group_uds[[i]], weights = group_weights[[i]], sample = sample)
          )
        )
        mean_ud
      },
      label = paste("group", group_labels[i])
    )
    # with too few degrees of freedom for the area, pkde() returns the
    # population model instead of a UD (with a warning)
    if (!inherits(pop_ud, "UD")) {
      stop(
        "the population UD could not be estimated for group ",
        group_labels[i]
      )
    }
    pop_ud
  }
  # first on the grid of the individual UDs
  pop_uds <- lapply(seq_len(n_groups), function(i) {
    estimate_pop_ud(i, group_grids[[i]]$bbox)
  })
  # the population kernels are wider than the individual ones (pkde()
  # optimises their bandwidth for the population as a whole), so a population
  # UD estimated with pkde can extend beyond the grid of the individual UDs,
  # and lose the mass outside it: in that case, we extend the grid to contain
  # the population UD, and estimate it again
  if (method == "pkde") {
    new_bboxes <- pkde_extended_bboxes(
      pop_uds,
      group_grids,
      group_tels,
      group_uds,
      tolerance = tolerance,
      kernel = list(...)$kernel
    )
    for (i in seq_len(n_groups)) {
      if (!isTRUE(all.equal(new_bboxes[[i]], group_grids[[i]]$bbox))) {
        group_grids[[i]]$bbox <- new_bboxes[[i]]
        pop_uds[[i]] <- estimate_pop_ud(i, new_bboxes[[i]])
      }
    }
  }

  ## assemble the table of population UDs
  # the CRS of the UDs (from the rasters, which keep the original CRS)
  crs <- sf::st_crs(terra::crs(x$ud[[1]]))
  method_name <- if (method == "pkde") "pkde" else "akde_mean"
  pop_results <- lapply(seq_len(n_groups), function(i) {
    pop_ud <- pop_uds[[i]]
    bbox <- group_grids[[i]]$bbox
    ud <- ctmm_ud_to_rast(
      pop_ud,
      bbox = bbox,
      crs = crs,
      id = group_labels[i],
      model_name = "population",
      method = method_name
    )
    # row for the table to integrate the results
    res_tbl <- tibble::tibble(
      method = method_name,
      n_ud = length(rows_list[[i]]),
      dof_area = summary(pop_ud, units = FALSE)$DOF[["area"]],
      xmin = bbox[["xmin"]],
      ymin = bbox[["ymin"]],
      xmax = bbox[["xmax"]],
      ymax = bbox[["ymax"]],
      res = group_grids[[i]]$res
    )
    # the grouping variables come first
    if (!is.null(keys)) {
      res_tbl <- dplyr::bind_cols(keys[i, , drop = FALSE], res_tbl)
    }
    res_tbl$ud <- list(ud)
    res_tbl$ud_ctmm <- list(pop_ud)
    names(res_tbl$ud) <- names(res_tbl$ud_ctmm) <- group_labels[i]
    class(res_tbl) <- c("hr_tt_ud_tbl", class(res_tbl))
    # the isopleths, with the confidence intervals of their areas from the
    # ctmm UD
    if (!is.null(levels)) {
      res_tbl <- hr_tt_ud_iso(res_tbl, levels, ci_level = ci_level)
    }
    res_tbl
  })
  pop_results <- do.call(rbind, pop_results)

  # combining the groups with rbind() does not keep the class of the table
  table_class <- if (is.null(levels)) "hr_tt_ud_tbl" else "hr_tt_poly_tbl"
  class(pop_results) <- c(
    table_class,
    setdiff(class(pop_results), table_class)
  )
  pop_results
}

#' Check that x is a table of UDs estimated with hr_tt_akde()
#'
#' The class `hr_tt_ud_tbl` is lost when grouping, so we check the columns.
#'
#' @param x An object.
#' @returns `NULL`, invisibly, if `x` has the columns of a table of AKDE UDs.
#' @keywords internal
#' @noRd
stopifnot_akde_ud_table <- function(x) {
  required_cols <- c("xmin", "ymin", "xmax", "ymax", "res", "ud", "ud_ctmm")
  if (!inherits(x, "data.frame") || !all(required_cols %in% names(x))) {
    stop(
      "x must be a table of UDs estimated with hr_tt_akde() (with the ctmm ",
      "UDs in column ud_ctmm)"
    )
  }
  if (!all(vapply(x$ud_ctmm, inherits, logical(1), "UD"))) {
    stop("column ud_ctmm of x must contain ctmm UD objects")
  }
  invisible(NULL)
}

#' Get the weights of the UDs for a population UD
#'
#' Converts the `weights` argument of [hr_tt_akde_pop()] into the `weights`
#' argument of the `ctmm` function used to combine the UDs.
#'
#' @param x A table of AKDE UDs.
#' @param weights `NULL`, `TRUE` or the name of a column of `x`.
#' @param method The method used to combine the UDs.
#' @returns For equal weights, `FALSE` with `method = "pkde"` (as expected by
#'   [ctmm::pkde()]) or `NULL` with `method = "mean"` (as expected by
#'   `ctmm::mean.UD()`); `TRUE` for optimised weights (`method = "pkde"`
#'   only); or a numeric vector with one weight per row of `x`.
#' @keywords internal
#' @noRd
akde_pop_weights <- function(x, weights, method) {
  if (is.null(weights)) {
    return(if (method == "pkde") FALSE else NULL)
  }
  if (isTRUE(weights)) {
    if (method != "pkde") {
      stop("optimised weights (weights = TRUE) require method = \"pkde\"")
    }
    return(TRUE)
  }
  if (
    !is.character(weights) ||
      length(weights) != 1 ||
      !weights %in% names(x)
  ) {
    stop(
      "weights must be NULL, TRUE (with method = \"pkde\"), or the name of a ",
      "numeric column of x"
    )
  }
  ud_weights <- x[[weights]]
  if (!is.numeric(ud_weights) || any(!is.finite(ud_weights) | ud_weights < 0)) {
    stop("the weights in column ", weights, " must be non-negative numbers")
  }
  ud_weights
}

#' Get the telemetry object of the track of each UD, for pkde
#'
#' @param tracks The `move2` object used to estimate the UDs.
#' @param models The table of models used to estimate the UDs.
#' @param uds The list of `ctmm` UDs.
#' @returns An unnamed list with the `telemetry` object of the track of each
#'   UD (in the order of `uds`).
#' @keywords internal
#' @noRd
akde_pop_telemetry <- function(tracks, models, uds) {
  if (is.null(tracks) || is.null(models)) {
    stop(
      "method = \"pkde\" estimates the population UD from the locations of ",
      "the tracks: provide the tracks (`tracks`) and the models (`models`) ",
      "used to estimate the UDs with hr_tt_akde(), or use method = \"mean\""
    )
  }
  if (!inherits(tracks, "move2")) {
    stop("tracks must be a move2 object")
  }
  stopifnot_ctmm_tt_fit_tbl(models)
  if (sf::st_crs(tracks) != attr(models, "crs")) {
    stop(
      "tracks must have the same coordinate reference system used to fit ",
      "the models"
    )
  }
  # the track of each UD, as recorded in the ctmm UD object
  ud_tracks <- vapply(
    uds,
    function(ud) as.character(attr(ud, "info")$identity),
    character(1),
    USE.NAMES = FALSE
  )
  # convert the tracks with the same error columns used to fit the models
  # (needed by the error model, if one was fitted); the messages of ctmm on
  # the sampling intervals were already given when fitting the models
  tel_list <- suppressMessages(mt_as_telemetry(
    dplyr::ungroup(tracks),
    error_cols = attr(models, "error_cols")
  ))
  missing_tracks <- setdiff(ud_tracks, names(tel_list))
  if (length(missing_tracks) > 0) {
    stop(
      "tracks has no locations for track(s) ",
      paste(missing_tracks, collapse = ", "),
      " of the UDs"
    )
  }
  # the tracks must have a model (akde_group_models() is only used for its
  # checks), and be those used to estimate the UDs
  unique_tracks <- unique(ud_tracks)
  akde_group_models(models, unique_tracks) # nolint: object_usage_linter.
  check_akde_tracks_unchanged(models, tel_list[unique_tracks], unique_tracks)
  unname(tel_list[ud_tracks])
}

#' Extend the grids of population UDs estimated with pkde to contain them
#'
#' A population UD estimated with [ctmm::pkde()] on the grid of the
#' individual UDs can extend beyond it. The grid of each population UD with
#' more than `tolerance` of its mass outside the grid is extended (by whole
#' cells, so that it stays aligned with the original grid) to contain the
#' grid that [ctmm::pkde()] would have used by default. Groups that shared a
#' grid keep sharing it, so that their population UDs can still be compared.
#'
#' @param pop_uds The population UDs, one per group.
#' @param grids The grids of the population UDs, one per group (lists with
#'   the bounding box `bbox` and the resolution `res`).
#' @param tel_lists The lists of `telemetry` objects of the tracks of each
#'   group.
#' @param ud_lists The lists of individual `ctmm` UDs of each group.
#' @param tolerance The target error of the computations.
#' @param kernel The kernel used by [ctmm::pkde()] (`NULL` for the default).
#' @returns A list with the bounding box of the grid of each group (the
#'   original one if the grid did not need to be extended).
#' @keywords internal
#' @noRd
pkde_extended_bboxes <- function(
  pop_uds,
  grids,
  tel_lists,
  ud_lists,
  tolerance,
  kernel
) {
  bboxes <- lapply(grids, `[[`, "bbox")
  # the UDs with more than tolerance of their mass outside their grid
  grid_mass <- vapply(
    pop_uds,
    function(ud) sum(ud$PDF, na.rm = TRUE) * prod(ud$dr),
    numeric(1)
  )
  truncated <- which(grid_mass < 1 - tolerance)
  if (length(truncated) == 0) {
    return(bboxes)
  }
  # as in ctmm, the kernels are based on the individual models by default
  if (is.null(kernel)) {
    kernel <- "individual"
  }
  # extend each truncated grid to contain the default grid of pkde()
  bboxes[truncated] <- lapply(truncated, function(i) {
    required <- pkde_required_bbox(
      pop_uds[[i]],
      tel_lists[[i]],
      ud_lists[[i]],
      tolerance = tolerance,
      kernel = kernel
    )
    extend_bbox(bboxes[[i]], required, grids[[i]]$res)
  })
  # groups that shared a grid get the union of their extended grids
  grid_ids <- vapply(
    grids,
    function(g) paste(c(g$bbox, g$res), collapse = "_"),
    character(1)
  )
  bboxes <- lapply(grid_ids, function(id) bbox_union(bboxes[grid_ids == id]))
  # warn about very large grids, which are slow and use a lot of memory
  n_cells <- mapply(
    function(b, g) {
      ((b[["xmax"]] - b[["xmin"]]) / g$res) *
        ((b[["ymax"]] - b[["ymin"]]) / g$res)
    },
    bboxes,
    grids
  )
  if (any(n_cells > 1e7)) {
    warning(
      "the grid extended to contain the population UD has ",
      format(max(n_cells), big.mark = ","), " cells, which can be slow ",
      "and use a lot of memory; this can happen when the individuals of ",
      "a group are far apart (see Details in ?hr_tt_akde_pop)",
      call. = FALSE
    )
  }
  bboxes
}

#' Bounding box needed to contain a population UD estimated with pkde
#'
#' As in [ctmm::akde()], the grid must extend beyond the locations by the
#' quantile of the (population) kernels corresponding to `tolerance`, and
#' contain the 95% home range of the population model (with its upper
#' confidence limit at level `1 - tolerance`).
#'
#' @param pop_ud The population UD estimated with [ctmm::pkde()].
#' @param tel_list The list of `telemetry` objects of the group.
#' @param uds The list of individual `ctmm` UDs of the group.
#' @param tolerance The target error of the computations.
#' @param kernel The kernel used by [ctmm::pkde()] (`"individual"` or
#'   `"population"`).
#' @returns A named vector with `xmin`, `ymin`, `xmax` and `ymax`.
#' @keywords internal
#' @noRd
pkde_required_bbox <- function(pop_ud, tel_list, uds, tolerance, kernel) {
  pop_model <- attr(pop_ud, "CTMM")
  # the quantile of a bivariate Gaussian kernel containing 1 - tolerance of
  # its mass
  z <- sqrt(-2 * log(tolerance))
  # the locations of each track, extended by that quantile of its kernels;
  # the covariance of the kernels is the covariance of the individual model
  # (or of the population model, with kernel = "population") scaled by the
  # square of the population bandwidth h
  data_bboxes <- lapply(seq_along(tel_list), function(j) {
    sigma <- if (kernel == "population") {
      pop_model$sigma
    } else {
      attr(uds[[j]], "CTMM")$sigma
    }
    kernel_sd <- pop_ud$h * sqrt(diag(sigma))
    c(
      xmin = min(tel_list[[j]]$x) - z * kernel_sd[[1]],
      ymin = min(tel_list[[j]]$y) - z * kernel_sd[[2]],
      xmax = max(tel_list[[j]]$x) + z * kernel_sd[[1]],
      ymax = max(tel_list[[j]]$y) + z * kernel_sd[[2]]
    )
  })
  # the extent of the home range of the population model
  model_ext <- ctmm::extent(pop_model, level = 1 - tolerance)
  model_bbox <- c(
    xmin = model_ext["min", "x"],
    ymin = model_ext["min", "y"],
    xmax = model_ext["max", "x"],
    ymax = model_ext["max", "y"]
  )
  bbox_union(c(data_bboxes, list(model_bbox)))
}

#' Extend a bounding box by whole cells to contain another bounding box
#'
#' The sides of `bbox` are moved outwards by a whole number of cells (plus a
#' buffer of one cell, as in ctmm) where needed to contain `required`, so that
#' the extended grid stays aligned with the original one.
#'
#' @param bbox The bounding box of the grid (aligned to `res`).
#' @param required The bounding box that the grid must contain.
#' @param res The resolution of the grid.
#' @returns The extended bounding box.
#' @keywords internal
#' @noRd
extend_bbox <- function(bbox, required, res) {
  grow_min <- function(side, req) {
    if (req < side) side - (ceiling((side - req) / res) + 1) * res else side
  }
  grow_max <- function(side, req) {
    if (req > side) side + (ceiling((req - side) / res) + 1) * res else side
  }
  c(
    xmin = grow_min(bbox[["xmin"]], required[["xmin"]]),
    ymin = grow_min(bbox[["ymin"]], required[["ymin"]]),
    xmax = grow_max(bbox[["xmax"]], required[["xmax"]]),
    ymax = grow_max(bbox[["ymax"]], required[["ymax"]])
  )
}

#' Union of bounding boxes
#'
#' @param bboxes A list of named vectors with `xmin`, `ymin`, `xmax` and
#'   `ymax`.
#' @returns The smallest bounding box containing all the bounding boxes, as a
#'   named vector.
#' @keywords internal
#' @noRd
bbox_union <- function(bboxes) {
  side <- function(name) vapply(bboxes, `[[`, numeric(1), name)
  c(
    xmin = min(side("xmin")),
    ymin = min(side("ymin")),
    xmax = max(side("xmax")),
    ymax = max(side("ymax"))
  )
}
