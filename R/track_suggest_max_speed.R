#' Suggest a maximum speed for each track from the data
#'
#' This function suggests, for each track, a maximum speed that separates the
#' speeds of plausible steps from those of outliers, by looking for a break in
#' the distribution of the (log) speeds of the steps between consecutive
#' events. The suggestion can be used as `max_speed` in
#' [event_flag_mcconnell()] and [tt_clean_mcconnell()]. It is a wrapper around
#' [move2utils::mt_suggest_speed_cap()], applied to each track separately,
#' which requires the suggested package `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' The suggestion is purely data-driven: check it against what is known about
#' the species (see also [max_speed_allometric()]). No suggestion (`NA`) is
#' given when no break is found, e.g. when a track has no outliers, or when it
#' has fewer than 10 steps with a positive speed. Events without a location
#' are ignored.
#'
#' To inspect the distribution of speeds of a track, or to obtain a single
#' suggestion pooling all tracks, use [move2utils::mt_suggest_speed_cap()]
#' directly.
#'
#' @param x A `move2` object.
#' @param method The method used to find the break, one of "auto" (the
#'   default; an entropy-based method, falling back to a broken-stick method
#'   validated with a dip test), "entropy" or "gap". See
#'   [move2utils::mt_suggest_speed_cap()].
#' @param threshold A numeric value passed to the method used to find the
#'   break. The default `NULL` uses the default of `move2utils`.
#' @param units The units of the returned speeds, as a `units` object (e.g.
#'   `as_units("km/h")`). Defaults to m/s.
#' @returns A `units` vector with the suggested maximum speed for each track
#'   (in the same order as the tracks in the metadata, see [show_meta()]),
#'   named by track id, with `NA` for the tracks for which no break was found.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' track_suggest_max_speed(example_tt)
track_suggest_max_speed <- function(
  x,
  method = c("auto", "entropy", "gap"),
  threshold = NULL,
  units = as_units("m/s")
) {
  check_move2utils("track_suggest_max_speed") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (!inherits(units, "units")) {
    stop("units must be a units object: e.g. as_units('m/s')")
  }
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  method <- match.arg(method)

  # get the track ids before removing events without a location, which could
  # remove whole tracks
  track_ids <- as.character(show_meta(x)[[move2::mt_track_id_column(x)]])
  x <- prepare_for_move2utils(x) # nolint: object_usage_linter.
  event_ids <- as.character(event_track_id(x))

  suggested <- vapply(
    track_ids,
    function(id) {
      x_track <- x[event_ids == id, ]
      if (nrow(x_track) < 2) {
        return(NA_real_)
      }
      args <- move2utils_args( # nolint: object_usage_linter.
        move2utils::mt_suggest_speed_cap,
        list(x_track, method = method, threshold = threshold)
      )
      as.numeric(do.call(move2utils::mt_suggest_speed_cap, args))
    },
    numeric(1)
  )

  suggested <- units::as_units(suggested, "m/s")
  units(suggested) <- units(units)
  suggested
}
