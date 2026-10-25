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
#' # population UD with population kernel density estimation
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
  # Check if levels are valid
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
  # a population UD needs at least two individual UDs
  too_small <- lengths(rows_list) < 2
  if (any(too_small)) {
    stop(
      "each group must contain at least two UDs to estimate a population UD ",
      "(group(s) ", paste(group_labels[too_small], collapse = ", "), ")"
    )
  }

  # the weight of each UD (NULL for equal weights, TRUE for optimised weights
  # with pkde, or a numeric vector with one value per row of x)
  ud_weights <- akde_pop_weights(x, weights, method)

  # the track of each UD, as recorded in the ctmm UD object
  ud_tracks <- vapply(
    x$ud_ctmm,
    function(ud) as.character(attr(ud, "info")$identity),
    character(1),
    USE.NAMES = FALSE
  )
  # pkde estimates the population UD from the locations of the tracks
  if (method == "pkde") {
    tel_list <- akde_pop_telemetry(tracks, models, ud_tracks)
  }

  # the CRS of the UDs (from the rasters, which keep the original CRS)
  crs <- sf::st_crs(terra::crs(x$ud[[1]]))

  # the grid of each group: all the UDs of a group must be on the same grid
  group_grids <- lapply(seq_along(rows_list), function(i) {
    grid_cols <- c("xmin", "ymin", "xmax", "ymax", "res")
    grid_tbl <- dplyr::distinct(tibble::as_tibble(x)[rows_list[[i]], grid_cols])
    if (nrow(grid_tbl) != 1) {
      stop(
        "all the UDs of group ", group_labels[i], " must be on the same grid ",
        "(e.g. estimated by hr_tt_akde() without a bbox for each group)"
      )
    }
    list(
      bbox = unlist(grid_tbl[1, c("xmin", "ymin", "xmax", "ymax")]),
      res = grid_tbl$res
    )
  })

  # estimate the population UD of group i on the grid defined by bbox
  estimate_pop_ud <- function(i, bbox) {
    rows <- rows_list[[i]]
    uds <- unname(x$ud_ctmm[rows])
    group_weights <- if (is.numeric(ud_weights)) {
      ud_weights[rows]
    } else {
      ud_weights
    }
    pop_ud <- with_label_warnings(
      if (method == "pkde") {
        # population kernel density estimate from the locations of the tracks
        ctmm::pkde(
          unname(tel_list[ud_tracks[rows]]),
          uds,
          weights = if (is.null(group_weights)) FALSE else group_weights,
          error = tolerance,
          grid = akde_grid(bbox, group_grids[[i]]$res),
          trace = FALSE,
          ...
        )
      } else {
        # average of the UDs (with a population model for the uncertainty);
        # mean() prints the model selection of the population model, which
        # we capture to avoid cluttering the console
        mean_ud <- NULL
        utils::capture.output(
          mean_ud <- suppressMessages(
            mean(uds, weights = group_weights, sample = sample)
          )
        )
        mean_ud
      },
      label = paste("group", group_labels[i])
    )
    if (!inherits(pop_ud, "UD")) {
      stop(
        "the population UD could not be estimated for group ",
        group_labels[i]
      )
    }
    pop_ud
  }

  # estimate the population UDs on the grids of the individual UDs
  group_bboxes <- lapply(group_grids, function(g) g$bbox)
  pop_uds <- lapply(
    seq_along(rows_list),
    function(i) estimate_pop_ud(i, group_bboxes[[i]])
  )

  # population kernels are wider than individual ones, so a population UD
  # estimated with pkde can extend beyond the grid of the individual UDs; in
  # that case, we extend the grid (by whole cells, so that it stays aligned
  # with the original grid) to contain the population UD, and estimate it
  # again
  if (method == "pkde") {
    pop_mass <- vapply(
      pop_uds,
      function(ud) sum(ud$PDF, na.rm = TRUE) * prod(ud$dr),
      numeric(1)
    )
    truncated <- pop_mass < 1 - tolerance
    if (any(truncated)) {
      kernel <- list(...)$kernel
      if (is.null(kernel)) {
        kernel <- "individual"
      }
      new_bboxes <- lapply(seq_along(rows_list), function(i) {
        if (!truncated[i]) {
          return(group_bboxes[[i]])
        }
        required <- pkde_required_bbox(
          pop_uds[[i]],
          unname(tel_list[ud_tracks[rows_list[[i]]]]),
          unname(x$ud_ctmm[rows_list[[i]]]),
          tolerance = tolerance,
          kernel = kernel
        )
        extend_bbox(group_bboxes[[i]], required, group_grids[[i]]$res)
      })
      # groups that shared a grid keep sharing it, so that their population
      # UDs can still be compared
      grid_ids <- vapply(
        group_grids,
        function(g) paste(c(g$bbox, g$res), collapse = "_"),
        character(1)
      )
      for (grid_id in unique(grid_ids)) {
        same_grid <- which(grid_ids == grid_id)
        shared_bbox <- c(
          xmin = min(vapply(new_bboxes[same_grid], `[[`, numeric(1), "xmin")),
          ymin = min(vapply(new_bboxes[same_grid], `[[`, numeric(1), "ymin")),
          xmax = max(vapply(new_bboxes[same_grid], `[[`, numeric(1), "xmax")),
          ymax = max(vapply(new_bboxes[same_grid], `[[`, numeric(1), "ymax"))
        )
        for (i in same_grid) {
          new_bboxes[[i]] <- shared_bbox
        }
      }
      # warn about very large grids, which are slow and use a lot of memory
      n_cells <- vapply(
        seq_along(rows_list),
        function(i) {
          b <- new_bboxes[[i]]
          r <- group_grids[[i]]$res
          ((b[["xmax"]] - b[["xmin"]]) / r) * ((b[["ymax"]] - b[["ymin"]]) / r)
        },
        numeric(1)
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
      # estimate again the population UDs whose grid has changed
      for (i in seq_along(rows_list)) {
        if (!isTRUE(all.equal(new_bboxes[[i]], group_bboxes[[i]]))) {
          pop_uds[[i]] <- estimate_pop_ud(i, new_bboxes[[i]])
          group_bboxes[[i]] <- new_bboxes[[i]]
        }
      }
    }
  }

  ## assemble the table of population UDs
  method_name <- if (method == "pkde") "pkde" else "akde_mean"
  pop_results <- lapply(seq_along(rows_list), function(i) {
    pop_ud <- pop_uds[[i]]
    bbox_val <- group_bboxes[[i]]
    ud <- ctmm_ud_to_rast(
      pop_ud,
      bbox = bbox_val,
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
      xmin = bbox_val[["xmin"]],
      ymin = bbox_val[["ymin"]],
      xmax = bbox_val[["xmax"]],
      ymax = bbox_val[["ymax"]],
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
#' @param x A table of AKDE UDs.
#' @param weights `NULL`, `TRUE` or the name of a column of `x`.
#' @param method The method used to combine the UDs.
#' @returns `NULL` (equal weights), `TRUE` (optimised weights) or a numeric
#'   vector with one weight per row of `x`.
#' @keywords internal
#' @noRd
akde_pop_weights <- function(x, weights, method) {
  if (is.null(weights)) {
    return(NULL)
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

#' Get the telemetry objects of the tracks of the UDs, for pkde
#'
#' @param tracks The `move2` object used to estimate the UDs.
#' @param models The table of models used to estimate the UDs.
#' @param ud_tracks The track id of each UD.
#' @returns A list of `telemetry` objects, named by track id.
#' @keywords internal
#' @noRd
akde_pop_telemetry <- function(tracks, models, ud_tracks) {
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
  # convert the tracks with the same error columns used to fit the models
  tel_list <- suppressMessages(mt_as_telemetry(
    dplyr::ungroup(tracks),
    error_cols = attr(models, "error_cols")
  ))
  missing_tracks <- setdiff(ud_tracks, names(tel_list))
  if (length(missing_tracks) > 0) {
    stop(
      "tracks has no locations for track(s) ",
      paste(unique(missing_tracks), collapse = ", "),
      " of the UDs"
    )
  }
  # the tracks must have a model, and be those used to estimate the UDs
  ud_tracks <- unique(ud_tracks)
  akde_group_models(models, ud_tracks) # nolint: object_usage_linter.
  check_akde_tracks_unchanged(models, tel_list[ud_tracks], ud_tracks)
  tel_list
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
  # the quantile of a bivariate Gaussian kernel containing 1 - tolerance of
  # its mass
  z <- sqrt(-2 * log(tolerance))
  pop_model <- attr(pop_ud, "CTMM")
  # the kernels are proportional (by the relative bandwidth h) to the
  # covariance of the individual or of the population model
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
  side <- function(name) vapply(data_bboxes, `[[`, numeric(1), name)
  c(
    xmin = min(side("xmin"), model_ext["min", "x"]),
    ymin = min(side("ymin"), model_ext["min", "y"]),
    xmax = max(side("xmax"), model_ext["max", "x"]),
    ymax = max(side("ymax"), model_ext["max", "y"])
  )
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
