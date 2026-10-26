#' Fit continuous-time movement models to each track with `ctmm`
#'
#' This function fits a continuous-time movement model, using the package
#' `ctmm`, to each track of a tibble of tracks. The fitted models are returned
#' in a tibble with one row per track, in the same order as the tracks in the
#' metadata (see [show_meta()]), so that they can be easily combined with the
#' metadata for further analyses. The table of models is the starting point
#' for the analyses that rely on `ctmm`, such as the estimation of home ranges
#' with autocorrelated kernel density estimation ([hr_tt_akde()]).
#'
#' @details Fitting is done in two steps, as recommended by `ctmm`: first,
#'   initial values of the parameters are guessed from the empirical variogram
#'   of each track ([ctmm::ctmm.guess()]), and then the model is fitted by
#'   maximum likelihood ([ctmm::ctmm.fit()]). With `model = "auto"` (the
#'   default), a series of candidate models is fitted and the best one is
#'   selected based on an information criterion ([ctmm::ctmm.select()]).
#'   This is the most appropriate approach in most cases, but it can be slow
#'   for long tracks. It is always good practice to inspect the fit of the
#'   models (e.g. by comparing the variogram of each track with the fitted
#'   model, see the "Movement models with ctmm" article).
#'
#'   Models are fitted to each track separately. To fit models at a
#'   different level (e.g. to each trip, or to each season of a track), first
#'   make that level the track of `x`, e.g. with [tt_split_trips()] or
#'   [move2::mt_set_track_id()].
#'
#'   The track data are converted with [mt_as_telemetry()], so `x` must be in a
#'   projected coordinate reference system with units in metres (see
#'   [mt_as_telemetry()] for details).
#'
#'   If the model cannot be fitted for a track (e.g. because the track has too
#'   few locations), a warning is given, and the track is kept in the table
#'   with a `NULL` model, and the error message in column `fit_message`, so
#'   that the table always has one row per track in the metadata. Warnings
#'   raised by `ctmm` while fitting are reported with the id of the track.
#'
#' @param x A `move2` object, in a projected coordinate reference system with
#'   units in metres. It can be grouped by its track id column, but not by
#'   other variables (see Details).
#' @param model The movement model to fit. Either one of:
#'   - `"auto"` (the default): select the best model with
#'   [ctmm::ctmm.select()], which starts from the model suggested by the
#'   variogram of the track (generally an anisotropic Ornstein-Uhlenbeck
#'   foraging process), and fits simpler models (e.g. isotropic,
#'   Ornstein-Uhlenbeck, or independent locations) until the information
#'   criterion no longer improves.
#'   - `"iid"`: independent and identically distributed locations (i.e. no
#'   autocorrelation).
#'   - `"ou"`: Ornstein-Uhlenbeck process (autocorrelated positions, with a
#'   home range).
#'   - `"ouf"`: Ornstein-Uhlenbeck foraging process (autocorrelated
#'   positions and velocities, with a home range).
#'   - `"bm"`: Brownian motion (no home range).
#'   - a model template created with [ctmm::ctmm()], which is fitted to every
#'   track with [ctmm::ctmm.fit()].
#'   - a list of such templates, one per track, either named by track id or in
#'   the order of the metadata.
#' @param error Logical; whether to fit a model of location error. If the
#'   tracks have information on the error of each location (e.g. dilution of
#'   precision, see `error_cols`), it is used by the error model. With a model
#'   template, `error = TRUE` adds the error model to the template, unless the
#'   template already has one (e.g. `ctmm::ctmm(error = TRUE)`); with
#'   `error = FALSE`, the error model of the template (if any) is kept.
#' @param uere A User Equivalent Range Error (in metres) used to calibrate the
#'   location error (see [ctmm::uere()]), or an object created with
#'   [ctmm::uere.fit()] from calibration data. If set, the error model is fitted
#'   (i.e. `error` is set to `TRUE`), also for model templates.
#' @param ic The information criterion used to select the best model when
#'   `model = "auto"` (see [ctmm::ctmm.select()]). Default is `"AICc"`.
#' @param candidates Logical; if `TRUE` and `model = "auto"`, all the candidate
#'   models fitted by [ctmm::ctmm.select()], ranked by `ic`, are returned in the
#'   list-column `candidates`. Default is `FALSE`.
#' @param error_cols The columns of the event data with information on the
#'   error of the locations, passed to [mt_as_telemetry()]. The same columns
#'   are used by the other functions that use the fitted models.
#' @param cores The number of cores used by [ctmm::ctmm.select()] to fit the
#'   candidate models in parallel (only used with `model = "auto"`).
#' @param ... Additional arguments passed to [ctmm::ctmm.select()] (if
#'   `model = "auto"`) or [ctmm::ctmm.fit()] (otherwise), e.g. `method` or
#'   `control`.
#' @returns A tibble of class `ctmm_tt_fit_tbl`, with one row per track, in
#'   the order of the metadata, and columns:
#' - the track id column (as named in `x`)
#' - `model`: a list-column of the fitted `ctmm` models (`NULL` if the model
#'   could not be fitted)
#' - `model_name`: the name of the fitted model (e.g. `"OUF anisotropic"`)
#' - `aicc`: the corrected Akaike Information Criterion of the fitted model
#' - `dof_area`: the effective number of degrees of freedom for the estimate
#'   of the home range area (small values, e.g. below 5-10, imply very
#'   uncertain home range estimates)
#' - `n_events`, `t_start`, `t_end`: the number of events with a location
#'   used to fit the model, and the time of the first and last event; these
#'   are used by other functions to check that the tracks have not changed
#'   since the models were fitted
#' - `fit_message`: `NA`, or the error message if the model could not be
#'   fitted
#' - `candidates` (only if `candidates = TRUE`): a list-column of the
#'   candidate models
#'
#' The coordinate reference system of `x` and the error columns used are
#' stored as attributes of the table.
#' @seealso [ctmm_tt_summary()] to summarise the parameters of the models,
#'   [hr_tt_akde()] to estimate home ranges from the models.
#' @export
#' @examplesIf rlang::is_installed("ctmm")
#' # the buffalo dataset from ctmm, converted to a tibble of tracks
#' data(buffalo, package = "ctmm")
#' buffalo_tt <- mt_as_move2(buffalo)
#' # we use a subset of the first two buffalo to make the example fast
#' buffalo_sub <- buffalo_tt %>%
#'   filter_by_meta(track %in% c("Cilla", "Gabs")) %>%
#'   dplyr::group_by(track) %>%
#'   dplyr::slice_head(n = 100) %>%
#'   dplyr::ungroup()
#' buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#' buffalo_fit
ctmm_tt_fit <- function(
  x,
  model = "auto",
  error = FALSE,
  uere = NULL,
  ic = "AICc",
  candidates = FALSE,
  error_cols = "auto",
  cores = 1,
  ...
) {
  check_ctmm_installed()
  ## check the inputs
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  id_col <- move2::mt_track_id_column(x)
  # models are fitted to each track, so x can only be grouped by track (in
  # which case the grouping adds nothing, and we drop it)
  if (inherits(x, "grouped_df")) {
    if (!identical(dplyr::group_vars(x), id_col)) {
      stop(
        "models are fitted to each track, so x can only be grouped by its ",
        "track id column ('", id_col, "'); to fit models to other units ",
        "(e.g. trips or seasons), make them the tracks of x first, e.g. with ",
        "`tt_split_trips()` or `move2::mt_set_track_id()`"
      )
    }
    x <- dplyr::ungroup(x)
  }
  if (!is.logical(error) || length(error) != 1 || is.na(error)) {
    stop("error must be TRUE or FALSE")
  }
  if (!is.logical(candidates) || length(candidates) != 1 || is.na(candidates)) {
    stop("candidates must be TRUE or FALSE")
  }

  # the track ids, in the order of the metadata (the order of the output);
  # the labels (as character) are used to match tracks and models by name
  meta_ids <- show_meta(x)[[id_col]]
  meta_labels <- as.character(meta_ids)
  # one model specification (a keyword or a ctmm template) per track
  track_models <- ctmm_model_list(model, meta_labels)
  # candidate models only exist when the model is selected by ctmm.select()
  if (candidates && !(is.character(model) && model == "auto")) {
    warning("candidates are only returned with model = \"auto\"")
    candidates <- FALSE
  }

  ## fit the models
  # find the error columns once, so that we can store them with the models
  # (the other functions that use the models must pass the same columns)
  error_cols <- ctmm_error_cols(x, error_cols)
  # convert the tracks to telemetry objects (a list named by track id)
  tel_list <- mt_as_telemetry(x, error_cols = error_cols)
  # fit the model to each track (in the order of the metadata); each element
  # is a list with the fit, the candidate models and the error message
  fits <- lapply(seq_along(meta_labels), function(i) {
    track_label <- meta_labels[i]
    # tracks without locations are not in tel_list
    if (!track_label %in% names(tel_list)) {
      return(ctmm_fit_result(
        message = "the track has no events with a location"
      ))
    }
    fit_ctmm_track(
      tel = tel_list[[track_label]],
      model = track_models[[i]],
      error = error,
      uere = uere,
      ic = ic,
      cores = cores,
      track_label = track_label,
      ...
    )
  })

  ## assemble the table of models
  # the models (NULL for the tracks that could not be fitted), with a summary
  # of each; the list-column of models is named by track id
  model_fits <- lapply(fits, function(f) f$fit)
  fit_tbl <- tibble::tibble(
    !!id_col := meta_ids,
    model = stats::setNames(model_fits, meta_labels),
    model_name = vapply(model_fits, ctmm_model_name, character(1)),
    aicc = vapply(model_fits, ctmm_model_aicc, numeric(1)),
    dof_area = vapply(model_fits, ctmm_dof_area, numeric(1))
  )
  # the number of events and the time range of each track, to check later
  # that the tracks have not changed since the models were fitted
  fit_tbl <- dplyr::bind_cols(
    fit_tbl,
    ctmm_track_fingerprint(tel_list, meta_labels)
  )
  fit_tbl$fit_message <- vapply(fits, function(f) f$message, character(1))
  if (candidates) {
    fit_tbl$candidates <- stats::setNames(
      lapply(fits, function(f) f$candidates),
      meta_labels
    )
  }

  # warn about the tracks for which the model could not be fitted
  failed <- !is.na(fit_tbl$fit_message)
  if (any(failed)) {
    warning(
      "the model could not be fitted for track(s) ",
      paste(meta_labels[failed], collapse = ", "),
      "; see column `fit_message` for details",
      call. = FALSE
    )
  }

  # store the information needed to use the models with the original data:
  # the CRS of the coordinates the models were fitted to, the error columns
  # used, and the column that identifies the tracks
  attr(fit_tbl, "crs") <- sf::st_crs(x)
  attr(fit_tbl, "error_cols") <- error_cols
  attr(fit_tbl, "track_id_column") <- id_col
  class(fit_tbl) <- c("ctmm_tt_fit_tbl", class(fit_tbl))
  fit_tbl
}

#' Fit a ctmm model to a single track, catching errors
#'
#' The model is fitted with `fit_ctmm_model()`. Warnings raised by `ctmm` are
#' prefixed with the id of the track, and errors are caught, so that a track
#' that cannot be fitted does not stop the fitting of the other tracks.
#'
#' @param tel,model,error,uere,ic,cores,... Passed to `fit_ctmm_model()`.
#' @param track_label The id of the track (used in warnings).
#' @returns A list created by `ctmm_fit_result()`: the fitted model and the
#'   candidate models, or the error message if the model could not be fitted.
#' @keywords internal
#' @noRd
fit_ctmm_track <- function(
  tel,
  model,
  error,
  uere,
  ic,
  cores,
  track_label,
  ...
) {
  tryCatch(
    with_label_warnings(
      fit_ctmm_model(
        tel,
        model = model,
        error = error,
        uere = uere,
        ic = ic,
        cores = cores,
        ...
      ),
      label = paste("track", track_label)
    ),
    # if the model could not be fitted, record the error message
    error = function(e) ctmm_fit_result(message = conditionMessage(e))
  )
}

#' Fit a ctmm model to a single track
#'
#' @param tel A `ctmm` `telemetry` object.
#' @param model A model keyword (`"auto"`, `"iid"`, `"ou"`, `"ouf"` or `"bm"`)
#'   or a `ctmm` model template.
#' @param error Logical; whether to fit an error model.
#' @param uere A UERE value or object (or `NULL`).
#' @param ic The information criterion for model selection.
#' @param cores The number of cores for model selection.
#' @param ... Additional arguments passed to `ctmm.select()` or `ctmm.fit()`.
#' @returns A list created by `ctmm_fit_result()`, with the fitted model and
#'   the candidate models (only for `"auto"`).
#' @keywords internal
#' @noRd
fit_ctmm_model <- function(tel, model, error, uere, ic, cores, ...) {
  # calibrate the location error, which implies fitting an error model
  if (!is.null(uere)) {
    ctmm::uere(tel) <- uere
    error <- TRUE
  }
  candidates <- NULL
  if (inherits(model, "ctmm")) {
    # a template provided by the user is fitted as it is, except that, with
    # error = TRUE (or a uere), we add the error model if the template does
    # not have one (ctmm.fit() only fits the error model of the template); we
    # set the same fields as ctmm::ctmm(error = TRUE), and keep the error of a
    # template that has one (e.g. a numeric initial value of the error)
    if (error && !any(model$error > 0)) {
      model$error <- TRUE
      model$errors <- TRUE
    }
    fit <- ctmm::ctmm.fit(tel, model, ...)
  } else if (model %in% c("iid", "bm")) {
    # models without autocorrelation of positions (iid: no time scale), or
    # without a home range (bm: an infinite time scale of positions), do not
    # need initial values for the time scales
    tau <- if (model == "iid") NULL else Inf
    fit <- ctmm::ctmm.fit(tel, ctmm::ctmm(tau = tau, error = error), ...)
  } else {
    # the other models start from initial values of the parameters guessed
    # from the variogram of the track
    guess <- ctmm::ctmm.guess(
      tel,
      CTMM = ctmm::ctmm(error = error),
      interactive = FALSE
    )
    if (model == "auto") {
      # fit all the candidate models (verbose = TRUE returns all of them,
      # ranked by ic), the best is first
      candidates <- ctmm::ctmm.select(
        tel,
        guess,
        IC = ic,
        verbose = TRUE,
        cores = cores,
        ...
      )
      fit <- candidates[[1]]
    } else {
      # the guess has two time scales (position and velocity); the OU model
      # only uses the first one
      tau <- if (model == "ou") guess$tau[1] else guess$tau[1:2]
      fit <- ctmm::ctmm.fit(tel, ctmm::ctmm(tau = tau, error = error), ...)
    }
  }
  ctmm_fit_result(fit = fit, candidates = candidates)
}

#' The result of fitting the model of a track
#'
#' @param fit The fitted `ctmm` model, or `NULL` if it could not be fitted.
#' @param candidates The candidate models (only with `model = "auto"`), or
#'   `NULL`.
#' @param message `NA`, or the error message if the model could not be
#'   fitted.
#' @returns A list with elements `fit`, `candidates` and `message`.
#' @keywords internal
#' @noRd
ctmm_fit_result <- function(
  fit = NULL,
  candidates = NULL,
  message = NA_character_
) {
  list(fit = fit, candidates = candidates, message = message)
}

#' Evaluate an expression, prefixing any warning with a label
#'
#' Warnings raised by `ctmm` do not say which track they refer to; this
#' function re-raises them with a label (e.g. the id of the track).
#'
#' @param expr The expression to evaluate.
#' @param label The label to prefix to the warnings.
#' @returns The value of `expr`.
#' @keywords internal
#' @noRd
with_label_warnings <- function(expr, label) {
  withCallingHandlers(
    expr,
    warning = function(w) {
      # raise the labelled warning, and muffle the original one
      warning(label, ": ", conditionMessage(w), call. = FALSE)
      invokeRestart("muffleWarning")
    }
  )
}

#' Create a list of model specifications, one per track
#'
#' @param model A model keyword, a `ctmm` template, or a list of templates
#'   (named by track id or in the order of the metadata).
#' @param meta_labels The track ids (as character), in the order of the
#'   metadata.
#' @returns A list with one element (a keyword or a `ctmm` template) per
#'   track.
#' @keywords internal
#' @noRd
ctmm_model_list <- function(model, meta_labels) {
  model_keywords <- c("auto", "iid", "ou", "ouf", "bm")
  # a single keyword or template is used for all tracks
  is_keyword <- is.character(model) &&
    length(model) == 1 &&
    model %in% model_keywords
  if (is_keyword || inherits(model, "ctmm")) {
    return(rep(list(model), length(meta_labels)))
  }
  # a list of templates, one per track
  if (is.list(model) && all(vapply(model, inherits, logical(1), "ctmm"))) {
    if (length(model) != length(meta_labels)) {
      stop(
        "a list of model templates must have one template per track ",
        "(", length(meta_labels), ")"
      )
    }
    # templates named by track id are matched to the tracks
    if (!is.null(names(model))) {
      if (!setequal(names(model), meta_labels)) {
        stop("the names of the list of model templates must be the track ids")
      }
      model <- model[meta_labels]
    }
    return(unname(model))
  }
  # anything else (including an unknown keyword) is not a valid model
  stop(
    "model must be one of ",
    paste0("\"", model_keywords, "\"", collapse = ", "),
    ", a ctmm model template, or a list of templates (one per track)"
  )
}

#' Extract information from a ctmm model (NA if the model is missing)
#'
#' @param fit A fitted `ctmm` model, or `NULL`.
#' @returns The name of the model, its AICc, or its degrees of freedom for the
#'   area.
#' @keywords internal
#' @noRd
ctmm_model_name <- function(fit) {
  if (is.null(fit)) {
    return(NA_character_)
  }
  # the name given by ctmm, e.g. "OUF anisotropic"
  summary(fit)$name
}

# the AICc is stored in the fitted model (NA if ctmm did not compute it)
ctmm_model_aicc <- function(fit) {
  if (is.null(fit) || is.null(fit$AICc)) {
    return(NA_real_)
  }
  fit$AICc
}

# the effective degrees of freedom of the parameters are given by the summary
# of the model, as a named vector (mean, area, diffusion, speed); models
# without a home range (e.g. Brownian motion) have 0 for the area
ctmm_dof_area <- function(fit) {
  if (is.null(fit)) {
    return(NA_real_)
  }
  dof <- summary(fit)$DOF
  if ("area" %in% names(dof)) dof[["area"]] else NA_real_
}

#' Number of events and time range of each track
#'
#' These values are stored in the table of models, so that we can check that
#' the tracks have not changed since the models were fitted.
#'
#' @param tel_list A list of `telemetry` objects, named by track id.
#' @param meta_labels The track ids (as character), in the order of the
#'   metadata.
#' @returns A tibble with columns `n_events`, `t_start` and `t_end`, with one
#'   row per element of `meta_labels`.
#' @keywords internal
#' @noRd
ctmm_track_fingerprint <- function(tel_list, meta_labels) {
  # tracks without locations are not in tel_list: they have no events, and
  # no time range
  n_events <- vapply(
    meta_labels,
    function(id) if (id %in% names(tel_list)) nrow(tel_list[[id]]) else 0L,
    integer(1),
    USE.NAMES = FALSE
  )
  # the time range of each track (a matrix with the start in the first row,
  # and the end in the second); ctmm stores times in column t, in seconds
  # since 1970-01-01 UTC
  t_range <- vapply(
    meta_labels,
    function(id) {
      if (id %in% names(tel_list)) range(tel_list[[id]]$t) else c(NA, NA)
    },
    numeric(2),
    USE.NAMES = FALSE
  )
  # times converted back to POSIXct
  tibble::tibble(
    n_events = n_events,
    t_start = as.POSIXct(t_range[1, ], origin = "1970-01-01", tz = "UTC"),
    t_end = as.POSIXct(t_range[2, ], origin = "1970-01-01", tz = "UTC")
  )
}

#' Check that an object is a table of ctmm models
#'
#' @param x An object.
#' @returns `NULL`, invisibly, if `x` is a table created by [ctmm_tt_fit()].
#' @keywords internal
#' @noRd
stopifnot_ctmm_tt_fit_tbl <- function(x) {
  # dplyr verbs keep the class of the table, but can drop the columns that
  # are needed to use the models (e.g. with dplyr::select())
  if (
    !inherits(x, "ctmm_tt_fit_tbl") ||
      !"model" %in% names(x) ||
      is.null(attr(x, "track_id_column")) ||
      !attr(x, "track_id_column") %in% names(x)
  ) {
    stop("the models must be a table of models created with ctmm_tt_fit()")
  }
  invisible(NULL)
}
