#' Clean a `move2` object using the outlier methods of move2utils
#'
#' This function detects outlying locations with one of the methods of the
#' package `move2utils` (see [event_flag_outliers()] for the methods), and
#' removes them, sets their location to empty, or replaces their location by
#' interpolation. It requires the suggested package `move2utils` (install it
#' with `remotes::install_github("move2universe/move2utils")`). To flag the
#' outliers without acting on them, use [event_flag_outliers()].
#'
#' @inheritParams event_flag_outliers
#' @param flag_action One of "remove", "null", or "interpolate", to either
#'   remove the outliers, keep their time stamp but set their location to
#'   NULL, or replace their location with a linearly interpolated location from
#'   the events that are not outliers.
#' @returns The `move2` object `x`, with the outliers acted on.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' tt_clean_outliers(example_tt, method = "detour")
tt_clean_outliers <- function(
  x,
  method = c("clean_track", "speed_cap", "detour", "bridge", "probability"),
  ...,
  flag_action = c("remove", "interpolate", "null")
) {
  flag_action <- match.arg(flag_action)
  valid <- event_flag_outliers( # nolint: object_usage_linter.
    x,
    method = method,
    ...
  )
  apply_flag_action(x, valid, flag_action) # nolint: object_usage_linter.
}
