#' Flag outliers using the methods of move2utils
#'
#' This function detects outlying locations with one of the methods of the
#' package `move2utils`, which requires the suggested package `move2utils`
#' (install it with `remotes::install_github("move2universe/move2utils")`).
#' Most methods choose their thresholds from the data, so, unlike
#' [event_flag_mcconnell()], they do not require a maximum speed.
#'
#' The available methods are:
#' * "clean_track" (the default): [move2utils::mt_clean_track()], which
#'   combines the methods below and iterates until no more outliers are found;
#'   it is the recommended starting point.
#' * "speed_cap": [move2utils::mt_flag_speed_cap()], which flags events on
#'   either side of an implausibly fast step, with a cap chosen from the data
#'   or given as `v_max` (with `threshold_type = "hard"`).
#' * "detour": [move2utils::mt_flag_outliers_detour()], which flags events
#'   for which the path to and from the neighbouring events is much longer
#'   than the direct distance between them (e.g. out-and-back spikes).
#' * "bridge": [move2utils::mt_flag_outliers_bridge()], which flags events
#'   that are far from where a Brownian bridge between the neighbouring events
#'   would put them.
#' * "probability": [move2utils::mt_flag_outliers()], which flags events
#'   with an improbable combination of speed, turning angle and their changes.
#'
#' Further arguments are passed to the `move2utils` function through `...`
#' (see its documentation for the options). Physical quantities must be given
#' as `units` objects (e.g. `v_max = as_units(50, "km/h")`), and are converted
#' to the units expected by `move2utils`: speeds (`v_max`,
#' `physiological_ceiling`), distances (`location_error`, `jitter`,
#' `residual_floor`, `step_floor`, `min_leg`) and masses (`mass`).
#' `location_error` (for the "clean_track" and "bridge" methods) can be a
#' single value, one value per event, the name of a column of `x` with the
#' errors (as a `units` object), or `"auto"`, with which `move2utils` uses the
#' column `eobs_horizontal_accuracy_estimate` (which must then be a `units`
#' object) or, failing that, the Argos location classes. The `move2utils`
#' functions are run without plots and messages; to inspect their
#' diagnostics, call them directly on `x`.
#'
#' `x` must be ordered by time within each track (see [tt_order_time()]).
#' Some methods also require events with duplicated times to be removed first
#' (e.g. with [move2::mt_filter_unique()]). Events without a location are
#' ignored, and returned as valid.
#'
#' @param x A `move2` object.
#' @param method The method used to detect outliers, one of "clean_track"
#'   (the default), "speed_cap", "detour", "bridge" or "probability" (see
#'   Details).
#' @param ... Further arguments passed to the `move2utils` function of the
#'   chosen method.
#' @returns A logical vector of the same length as the number of events in `x`,
#'   indicating which events are valid (`TRUE`) and which are outliers
#'   (`FALSE`).
#' @seealso [tt_clean_outliers()] to remove the outliers, or replace their
#'   location.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' event_flag_outliers(example_tt, method = "detour")
#' # use a maximum speed rather than one estimated from the data (steps in
#' # this toy dataset are hundreds of km long)
#' event_flag_outliers(
#'   example_tt,
#'   method = "speed_cap",
#'   v_max = as_units(1000, "km/h"),
#'   threshold_type = "hard"
#' )
event_flag_outliers <- function(
  x,
  method = c("clean_track", "speed_cap", "detour", "bridge", "probability"),
  ...
) {
  check_move2utils("event_flag_outliers") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # all methods work on step lengths and speeds in metres, which need a CRS
  # to be computed
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  # the speed cap and detour methods of move2utils use projected coordinates
  # as they are, assuming metres, so other projected units would silently give
  # wrong speeds and distances
  check_metric_crs(x) # nolint: object_usage_linter.
  method <- match.arg(method)
  # all these functions share the same interface (a move2 object in, the same
  # object out with a logical is_outlier column added), so only the function
  # changes with the method
  fn <- switch(method,
    clean_track = move2utils::mt_clean_track,
    speed_cap = move2utils::mt_flag_speed_cap,
    detour = move2utils::mt_flag_outliers_detour,
    bridge = move2utils::mt_flag_outliers_bridge,
    probability = move2utils::mt_flag_outliers
  )

  args <- list(...)
  # a column of errors, or one error per event, is stored in metres in a
  # column of x, so that it is subset with the events passed to move2utils
  # (which drops those without a location); a single value is left to
  # units_to_move2utils() below
  location_error <- args[["location_error"]]
  if (is.character(location_error) || length(location_error) > 1) {
    prepared <- outlier_location_error(x, location_error)
    x <- prepared$x
    args$location_error <- prepared$location_error
  }
  # move2utils takes physical quantities as plain numbers in fixed units
  # (e.g. v_max in m/s), so the units objects given through ... are converted
  # first; arguments that move2utils validates itself (thresholds, iterations,
  # etc.) are passed on unchanged. do.call() is needed to splice the converted
  # list into the call; x and fn are named so that an argument in ... cannot
  # be partially matched to them (e.g. f = 1 would otherwise replace fn)
  res <- do.call(
    call_move2utils, # nolint: object_usage_linter.
    c(
      list(x = x, fn = fn),
      units_to_move2utils(args), # nolint: object_usage_linter.
      list(cols = "is_outlier")
    )
  )
  # events without a location are not passed to move2utils and come back as
  # NA: they are returned as valid (as in event_flag_mcconnell()), as there
  # is no location to judge; %in% also treats any NA from move2utils itself
  # as not flagged
  !(res$is_outlier %in% TRUE)
}

#' Prepare a location error given by column or per event for move2utils
#'
#' `move2utils` takes the name of a column of `x` with the errors in metres,
#' or `"auto"`, with which it uses the column
#' `eobs_horizontal_accuracy_estimate` (in metres) or, failing that, the Argos
#' location classes. Columns must be `units` objects, which are converted to
#' metres in a copy of `x`, and errors given per event are stored in a new
#' column, so that they are subset with the events.
#'
#' @param x A `move2` object.
#' @param location_error The name of a column of `x`, `"auto"`, or a `units`
#'   object with one value per event.
#' @returns A list with `x` (with the errors in metres) and `location_error`
#'   (the name of the column, or `"auto"`, to pass to `move2utils`).
#' @keywords internal
#' @noRd
outlier_location_error <- function(x, location_error) {
  if (is.character(location_error) && length(location_error) == 1) {
    # with "auto", the Argos location classes are converted to metres by
    # move2utils, so only the accuracy of e-obs tags needs its units checked
    col <- if (location_error == "auto") {
      "eobs_horizontal_accuracy_estimate"
    } else {
      location_error
    }
    if (location_error != "auto" || col %in% names(x)) {
      error <- location_error_column(x, col) # nolint: object_usage_linter.
      x[[col]] <- as.numeric(units::set_units(error, "m", mode = "standard"))
    }
    return(list(x = x, location_error = location_error))
  }
  # one value per event (a single value does not get here)
  if (
    !inherits(location_error, "units") ||
      !units::ud_are_convertible(units::deparse_unit(location_error), "m")
  ) {
    stop(
      "location_error must be a units object (e.g. as_units(20, 'm')), ",
      "or the name of a column of x"
    )
  }
  if (length(location_error) != nrow(x)) {
    stop("location_error must have one value, or one value per event")
  }
  # a name that is unlikely to be a column of x already
  col <- ".tidytracks_location_error"
  x[[col]] <- as.numeric(
    units::set_units(location_error, "m", mode = "standard")
  )
  list(x = x, location_error = col)
}
