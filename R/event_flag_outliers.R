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
#'   or given as `v_max`.
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
#' `location_error` can also be the name of a column of `x` (with the errors
#' in metres). The `move2utils` functions are run without plots
#' and messages; to inspect their diagnostics, call them directly on `x`.
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
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  method <- match.arg(method)
  fn <- switch(method,
    clean_track = move2utils::mt_clean_track,
    speed_cap = move2utils::mt_flag_speed_cap,
    detour = move2utils::mt_flag_outliers_detour,
    bridge = move2utils::mt_flag_outliers_bridge,
    probability = move2utils::mt_flag_outliers
  )

  res <- do.call(
    call_move2utils, # nolint: object_usage_linter.
    c(
      list(x, fn),
      units_to_move2utils(list(...)), # nolint: object_usage_linter.
      list(cols = "is_outlier")
    )
  )
  # events without a location are not passed to move2utils, and are returned
  # as valid (as in event_flag_mcconnell())
  !(res$is_outlier %in% TRUE)
}
