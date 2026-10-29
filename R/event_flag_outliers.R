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
#' object) or, failing that, the Argos location classes. `state` (for the
#' "clean_track" method) can be the name of a column of `x`, or one value per
#' event. Each track is checked on its own, with all the arguments (unless
#' `pool_by` pools thresholds across tracks). The `move2utils` functions are
#' run without plots and messages; to inspect their diagnostics, call them
#' directly on `x`.
#'
#' `x` must be ordered by time within each track (see [tt_order_time()]).
#' Some methods also require events with duplicated times to be removed first
#' (e.g. with [move2::mt_filter_unique()]). Events without a location are
#' ignored, and returned as valid. Tracks with too few events with a location
#' for the method (10 for "clean_track", 5 for "probability", and 2 for the
#' other methods) are not checked, with a warning, and their events are
#' returned as valid.
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
  # likewise for a state given per event (for mt_clean_track(), which also
  # takes the name of a column)
  state <- args[["state"]]
  if (length(state) > 1) {
    if (length(state) != nrow(x)) {
      stop(
        "state must be the name of a column of x, or have one value per event"
      )
    }
    x[[".tidytracks_state"]] <- state
    args$state <- ".tidytracks_state"
  }
  # move2utils takes physical quantities as plain numbers in fixed units
  # (e.g. v_max in m/s), so the units objects given through ... are converted
  # first; arguments that move2utils validates itself (thresholds, iterations,
  # etc.) are passed on unchanged
  args <- units_to_move2utils(args) # nolint: object_usage_linter.
  # checked on all of x (call_move2utils() only sees the tracks checked
  # below, and none if all are short); subsetting events keeps the order
  check_time_ordered(x) # nolint: object_usage_linter.

  # move2utils processes each track separately, but fails when it combines
  # the results of a track too short for the method with those of other
  # tracks (and some methods fail on a short track on its own):
  # mt_clean_track() needs 10 locations (it returns shorter tracks without
  # flags), the probability method three steps with a turning angle (5
  # locations), and the other methods a step. shorter tracks are therefore
  # not passed to move2utils, and their events are returned as valid
  min_located <- switch(method, clean_track = 10, probability = 5, 2)
  located <- !sf::st_is_empty(x)
  ids <- as.character(event_track_id(x))
  # the number of events with a location in the track of each event
  n_located <- stats::ave(as.numeric(located), ids, FUN = sum)
  checked <- n_located >= min_located
  # tracks without any location have nothing to check, so no warning
  n_short <- length(unique(ids[located & !checked]))
  if (n_short > 0) {
    warning(
      n_short, " track(s) with fewer than ", min_located, " events with a ",
      "location were not checked for outliers; their events are returned ",
      "as valid"
    )
  }

  valid <- rep(TRUE, nrow(x))
  if (any(checked)) {
    # subsetting a move2 object is slow, so it is skipped when all tracks
    # are checked
    if (!all(checked)) {
      x <- x[checked, ]
    }
    # move2utils checks each track on its own (unless pool_by pools
    # thresholds across tracks), but finds the events of each track by
    # comparing the ids of all the events, and binds the results of all the
    # tracks as sf objects, which takes much longer than the methods
    # themselves with many tracks; mt_clean_track() also does not pass its
    # entropy, gap and persistence filter thresholds on to the tracks of an
    # object with several tracks. Without pool_by, each track is therefore
    # passed to move2utils on its own, and only its flags are kept
    track_ids <- ids[checked]
    track_rows <- if (is.null(args$pool_by)) {
      split(seq_len(nrow(x)), factor(track_ids, levels = unique(track_ids)))
    } else {
      list(seq_len(nrow(x)))
    }
    flagged <- rep(FALSE, nrow(x))
    for (rows in track_rows) {
      x_track <- if (length(track_rows) == 1) x else x[rows, ]
      # do.call() is needed to splice the arguments into the call; x and fn
      # are named so that an argument in ... cannot be partially matched to
      # them (e.g. f = 1 would otherwise replace fn). The order of the events
      # was checked above, for all the tracks
      res <- do.call(
        call_move2utils, # nolint: object_usage_linter.
        c(
          list(x = x_track, fn = fn),
          args,
          list(cols = "is_outlier", time_ordered = FALSE)
        )
      )
      # events without a location are not passed to move2utils and come back
      # as NA: they are returned as valid (as in event_flag_mcconnell()), as
      # there is no location to judge; %in% also treats any NA from
      # move2utils itself as not flagged
      flagged[rows] <- res$is_outlier %in% TRUE
    }
    valid[checked] <- !flagged
  }
  valid
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
