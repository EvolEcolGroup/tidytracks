#' Summarise the parameters of the movement models fitted with `ctmm`
#'
#' This function extracts the estimates of the parameters of the movement
#' models fitted with [ctmm_tt_fit()], with their confidence intervals (as
#' given by `summary()` on each model, see [ctmm::summary.ctmm()]). The table
#' has one row per track, in the same order as the table of models (and thus
#' of the metadata), so that it can be easily joined with the metadata (e.g.
#' to compare home range sizes between sexes).
#'
#' @details The parameters depend on the models: e.g. models without
#'   autocorrelation (`"IID"`) only have an `area`, Ornstein-Uhlenbeck models
#'   (`"OU"`) also have a time scale of the autocorrelation of positions
#'   (`tau_position`, the home range crossing time), and Ornstein-Uhlenbeck
#'   foraging models (`"OUF"`) also have a time scale of the autocorrelation of
#'   velocities (`tau_velocity`), and estimates of `speed`. The table has
#'   columns for all the parameters estimated for any track, and `NA` for the
#'   tracks whose model does not estimate a parameter.
#'
#'   Note that `area` is the area of the Gaussian home range of the model (at
#'   the 95% level), which is not the same as the home range estimated with
#'   [hr_tt_akde()] (which uses the model to estimate the utilisation
#'   distribution non-parametrically).
#'
#'   The values are returned as `units` objects in SI units (e.g. m^2 for
#'   areas, seconds for time scales); they can be converted to more convenient
#'   units with [units::set_units()] (e.g. `units::set_units(area_est, km^2)`).
#'
#' @param x A table of models created with [ctmm_tt_fit()].
#' @param level The confidence level of the intervals (default 0.95).
#' @returns A tibble with one row per track, and columns:
#' - the track id column (as in `x`)
#' - `model_name`: the name of the model
#' - `dof_area`: the effective number of degrees of freedom for the area
#' - for each parameter (e.g. `area`, `tau_position`, `tau_velocity`, `speed`,
#'   `diffusion`), three columns with the lower bound of the confidence
#'   interval (`_low`), the estimate (`_est`) and the upper bound (`_high`)
#' @seealso [ctmm_tt_fit()] to fit the models.
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
#' ctmm_tt_summary(buffalo_fit)
ctmm_tt_summary <- function(x, level = 0.95) {
  check_ctmm_installed()
  stopifnot_ctmm_tt_fit_tbl(x)
  if (
    !is.numeric(level) ||
      length(level) != 1 ||
      is.na(level) ||
      level <= 0 ||
      level >= 1
  ) {
    stop("level must be a single number between 0 and 1")
  }
  id_col <- attr(x, "track_id_column")

  # extract the confidence intervals of each model as a named vector (e.g.
  # area_low, area_est, area_high, tau_position_low, ...), or NULL for the
  # tracks whose model could not be fitted
  ci_list <- lapply(x$model, function(fit) {
    if (is.null(fit)) {
      return(NULL)
    }
    # a matrix with one row per parameter, and columns low, est and high;
    # units = FALSE returns all values in SI units
    ci <- summary(fit, level = level, units = FALSE)$CI
    params <- ctmm_param_names(rownames(ci))
    # flatten the matrix by row, so that the three values of each parameter
    # are next to each other
    values <- c(t(ci[, c("low", "est", "high"), drop = FALSE]))
    names(values) <- paste(
      rep(params, each = 3),
      c("low", "est", "high"),
      sep = "_"
    )
    values
  })

  # different models estimate different parameters: we take all the
  # parameters estimated for any track (in order of appearance), and fill a
  # matrix with one row per track, with NA for the parameters not in a model
  value_names <- unique(unlist(lapply(ci_list, names)))
  values <- matrix(
    NA_real_,
    nrow = nrow(x),
    ncol = length(value_names),
    dimnames = list(NULL, value_names)
  )
  for (i in seq_along(ci_list)) {
    values[i, names(ci_list[[i]])] <- ci_list[[i]]
  }

  summary_tbl <- tibble::tibble(
    !!id_col := x[[id_col]],
    model_name = x$model_name,
    dof_area = x$dof_area
  )
  # add the parameters as units objects (the units depend on the parameter,
  # which is the column name without its _low, _est or _high suffix)
  for (value_name in value_names) {
    param <- sub("_(low|est|high)$", "", value_name)
    summary_tbl[[value_name]] <- ctmm_param_units(values[, value_name], param)
  }
  summary_tbl
}

#' Convert the names of the parameters in a ctmm summary to snake case
#'
#' `summary(fit, units = FALSE)$CI` has row names such as
#' `"area (square meters)"` or `"τ[position] (seconds)"`; this function
#' converts them to names such as `area` and `tau_position`.
#'
#' @param x The row names of the confidence intervals.
#' @returns A character vector of parameter names.
#' @keywords internal
#' @noRd
ctmm_param_names <- function(x) {
  # the names are in UTF-8; we match them byte by byte, to avoid translating
  # them to the native encoding (which fails for the greek letters in
  # non-UTF-8 locales)
  # remove the units (in parentheses at the end)
  x <- sub("\\s*\\([^()]*\\)$", "", x, useBytes = TRUE)
  # the greek letter tau (bytes cf 84 in UTF-8) is spelled out
  tau <- rawToChar(as.raw(c(0xcf, 0x84)))
  x <- gsub(tau, "tau_", x, fixed = TRUE, useBytes = TRUE)
  # any other character that is not a letter or number becomes an underscore
  x <- gsub("[^A-Za-z0-9]+", "_", x, useBytes = TRUE)
  x <- gsub("^_+|_+$", "", x, useBytes = TRUE)
  tolower(x)
}

#' Add SI units to the values of a ctmm parameter
#'
#' @param x A numeric vector of values (in SI units).
#' @param param The name of the parameter (as returned by
#'   `ctmm_param_names()`).
#' @returns A `units` object, or `x` unchanged if the units of the parameter
#'   are not known.
#' @keywords internal
#' @noRd
ctmm_param_units <- function(x, param) {
  # SI units, as returned by summary(fit, units = FALSE); the time scales
  # include tau (for OUf models, whose two time scales are equal) and the
  # period of circulation (circle)
  param_units <- if (param == "area") {
    "m^2"
  } else if (startsWith(param, "tau_") || param %in% c("tau", "circle")) {
    "s"
  } else if (param == "speed") {
    "m/s"
  } else if (param == "diffusion") {
    "m^2/s"
  } else if (startsWith(param, "error")) {
    "m"
  } else {
    NULL
  }
  # parameters we do not know about are returned as plain numbers
  if (is.null(param_units)) {
    return(x)
  }
  units::as_units(x, param_units)
}
