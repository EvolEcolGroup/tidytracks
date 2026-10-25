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
#' are ignored. `x` must be ordered by time within each track (see
#' [tt_order_time()]), and have a geographic CRS or a projected CRS in metres
#' (`move2utils` takes projected coordinates to be in metres).
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
  # move2utils computes the speeds from the coordinates, so it needs to know
  # whether they are geographic or projected, and in which units
  if (is.na(sf::st_crs(x))) {
    stop("x must have a coordinate reference system (CRS) defined")
  }
  check_metric_crs(x) # nolint: object_usage_linter.
  # validated here so that a wrong method fails before any track is processed
  method <- match.arg(method)
  # mt_suggest_speed_cap() takes the steps between consecutive rows, so the
  # events must be ordered by time
  check_time_ordered(x) # nolint: object_usage_linter.

  # get the track ids before removing events without a location, which could
  # remove whole tracks: these tracks then get NA
  track_ids <- as.character(show_meta(x)[[move2::mt_track_id_column(x)]])
  # move2utils gives an error for events without a location; once they are
  # dropped, the steps are taken between the located events on either side
  x <- x[!sf::st_is_empty(x), ]
  event_ids <- as.character(event_track_id(x))

  # the same arguments are used for every track; plot = FALSE and
  # silent = TRUE stop move2utils drawing a density plot and printing
  # diagnostics for each track
  args <- move2utils_args( # nolint: object_usage_linter.
    move2utils::mt_suggest_speed_cap,
    list(method = method, threshold = threshold)
  )
  # mt_suggest_speed_cap() pools all the events it is given into a single
  # distribution of speeds, so it is called on each track separately to get
  # one suggestion per track; iterating over the metadata ids (rather than
  # splitting the events) returns the tracks in metadata order
  suggested <- vapply(
    track_ids,
    function(id) {
      x_track <- x[event_ids == id, ]
      # a track needs at least one step; move2utils returns NA anyway when
      # there are fewer than 10 steps with a positive speed, but is not
      # guaranteed to cope with an empty track
      if (nrow(x_track) < 2) {
        return(NA_real_)
      }
      # move2utils returns NA_real_ (not Inf) when no break is found, and
      # as.numeric() drops any attributes
      as.numeric(
        do.call(move2utils::mt_suggest_speed_cap, c(list(x_track), args))
      )
    },
    numeric(1)
  )

  # move2utils returns speeds in m/s; vapply() names them by track id
  suggested <- units::as_units(suggested, "m/s")
  units(suggested) <- units(units)
  suggested
}
