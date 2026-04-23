#' Extract event step segments as a LINESTRING sf object
#'
#' Converts a \code{move2} object into an \code{sf} data frame of step
#' segments (one LINESTRING per consecutive pair of events), preserving all
#' event-table columns. The final event of each track has no outgoing step and
#' is dropped.
#'
#' This is the recommended way to add track paths to a map that will be
#' animated with \code{\link{tt_animate_paths}}, because gganimate's
#' \code{transition_time} requires a homogeneous geometry type. The output is
#' suitable for use with \code{ggplot2::geom_sf()}.
#'
#' @param x A \code{move2} object.
#'
#' @return An \code{sf} data frame with LINESTRING geometry, one row per step.
#'   All event-table columns from \code{x} (including the track ID and datetime
#'   columns) are preserved.
#'
#' @examples
#' \dontrun{
#' segs <- tt_event_segments(df_p)
#'
#' ggplot() +
#'   geom_spatraster(data = bathy_p) +
#'   geom_sf(data = segs, aes(colour = track_id), linewidth = 1, alpha = 0.8) +
#'   geom_spatvector(data = land_p, fill = land_colour) +
#'   theme_void() |>
#'   tt_animate_paths(x = df_p)
#' }
#'
#' @export
tt_event_segments <- function(x) {

  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }

  data_steps <- x |>
    dplyr::mutate(geometry = move2::mt_segments(x))

  data_steps <- tt_drop_units(data_steps)

  # mt_segments() returns a POINT geometry for the final event of each track
  # (no outgoing step). Filter to LINESTRING only: mixed geometry types break
  # gganimate's transition_time.
  data_steps[sf::st_geometry_type(data_steps) == "LINESTRING", ]
}
