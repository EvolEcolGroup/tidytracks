#' Animate a user-built map with track paths or points
#'
#' Takes a \code{ggplot} object built by the user and adds gganimate animation
#' so that track data moves through time using
#' \code{\link[gganimate]{transition_time}}.
#'
#' The user first builds a complete map with all desired layers (raster
#' basemaps, polygon overlays, track data, themes, limits) and gets it looking
#' exactly right as a static plot. They then pipe it into this function to add
#' animation. Layers whose data do not contain the track datetime column (e.g.
#' a bathymetry raster or land polygons) are automatically kept static across
#' all frames by gganimate.
#'
#' The track data layer must be added with either \code{\link{geom_event_path}}
#' or \code{\link{geom_event_point}}. The function detects which is present
#' from the geometry type in the layer data and applies the appropriate
#' animation:
#'
#' \itemize{
#'   \item \strong{Path layer} (\code{geom_event_path}): if \code{fade = TRUE},
#'     segments fade out behind the current one; if \code{fade = FALSE}, all
#'     previous segments remain visible, producing a permanently growing path.
#'   \item \strong{Point layer} (\code{geom_event_point}): points move through
#'     time with a fading, shrinking wake regardless of \code{fade}.
#' }
#'
#' All aesthetic choices (colour, size, linewidth, alpha, etc.) are set by the
#' user in their \code{geom_event_path()} or \code{geom_event_point()} call.
#'
#' @param p A \code{ggplot} object containing the fully styled map, with the
#'   track layer added using \code{\link{geom_event_path}} or
#'   \code{\link{geom_event_point}}.
#' @param x A \code{move2} object. Used to identify the datetime column name
#'   and compute the number of animation frames.
#' @param fade Logical. Only relevant for path animations. If \code{TRUE}
#'   (default), previous segments fade out behind the current one using
#'   \code{\link{shadow_wake_build}}. If \code{FALSE}, all previous segments
#'   remain fully visible, producing a permanently growing path using
#'   \code{\link[gganimate]{shadow_mark}}.
#' @param wake_length Numeric between 0 (exclusive) and 1 (inclusive). Length
#'   of the fading trail as a proportion of the total animation length. Only
#'   used when \code{fade = TRUE} (paths) or for point animations. Default is
#'   \code{0.5}.
#' @param label_format A character string specifying the
#'   \code{\link[base]{format.POSIXct}} format for the date-time label shown on
#'   each frame. Default is \code{"\%Y-\%m-\%d \%H:\%M:\%S"}.
#'
#' @return A named list with:
#'   \describe{
#'     \item{\code{p_anim}}{A \code{gganim} object ready to pass to
#'       \code{\link[gganimate]{animate}}.}
#'     \item{\code{n_timesteps}}{The number of unique time steps in the layer data.
#'       Use as the \code{nframes} argument to \code{animate()} for a
#'       one-frame-per-timestep animation, or multiply (e.g.
#'       \code{nframes = result$n_timesteps * 5}) for smoother interpolated
#'       movement between steps.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Path animation: fading trail (default)
#' result <- ggplot() +
#'   geom_spatraster(data = bathy_p) +
#'   scale_fill_gradientn(colours = c("#08195e", "#85c1e9")) +
#'   geom_event_path(data = df_p,
#'                   aes(colour = track_id), linewidth = 1, alpha = 0.8) +
#'   scale_colour_manual(values = track_colours) +
#'   geom_spatvector(data = land_p, fill = land_colour, colour = land_colour) +
#'   theme_void() |>
#'   tt_animate_map(x = df_p, fade = TRUE, wake_length = 0.4,
#'                  label_format = "%Y-%m-%d %H:%M")
#'
#' # Path animation: permanently growing path
#' result <- ggplot() + ... |>
#'   tt_animate_map(x = df_p, fade = FALSE, label_format = "%Y-%m-%d %H:%M")
#'
#' # Point animation: moving points with fading wake
#' result <- ggplot() +
#'   geom_spatraster(data = bathy_p) +
#'   geom_event_point(data = df_p, aes(colour = track_id), size = 5) +
#'   theme_void() |>
#'   tt_animate_map(x = df_p, wake_length = 0.4,
#'                  label_format = "%Y-%m-%d %H:%M")
#'
#' # Render: one frame per timestep
#' gganimate::animate(result$p_anim, nframes = result$n_timesteps, fps = 10,
#'                    renderer = gganimate::av_renderer())
#'
#' # Render: smoother interpolated animation
#' gganimate::animate(result$p_anim, nframes = result$n_timesteps * 5, fps = 25,
#'                    renderer = gganimate::av_renderer())
#' }
#'
#' @export
tt_animate_map <- function(p,
                           x,
                           fade = TRUE,
                           wake_length = 0.5,
                           label_format = "%Y-%m-%d %H:%M:%S") {

  if (!inherits(p, "ggplot")) {
    stop("p must be a ggplot object")
  }
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (!is.logical(fade) || length(fade) != 1 || is.na(fade)) {
    stop("fade must be TRUE or FALSE")
  }
  if (!is.numeric(wake_length) || length(wake_length) != 1 ||
      wake_length <= 0 || wake_length > 1) {
    stop("wake_length must be a single numeric value greater than 0 and at most 1")
  }

  time_col <- move2::mt_time_column(x)
  detected  <- tt_detect_layer_type(p, time_col)

  if (is.null(detected)) {
    stop(
      "No supported track layer found. ",
      "Add a geom_event_path() or geom_event_point() layer to the plot."
    )
  }

  layer_type <- detected$type
  # Derive n_timesteps from the layer data itself: for path layers the final event
  # of each track is dropped by geom_event_path, so the layer may contain fewer
  # unique timestamps than x.
  n_timesteps <- length(unique(detected$data[[time_col]]))
  time_sym  <- rlang::sym(time_col)

  p_anim <- p + gganimate::transition_time(time = !!time_sym)

  if (layer_type == "path") {
    if (fade) {
      p_anim <- p_anim +
        shadow_wake_build(wake_length = wake_length,
                          size = FALSE, alpha = TRUE, wrap = FALSE)
    } else {
      p_anim <- p_anim +
        gganimate::shadow_mark(past = TRUE, future = FALSE)
    }
  } else {
    # point: always use a fading, shrinking wake
    p_anim <- p_anim +
      shadow_wake_build(
        wake_length = wake_length,
        size = TRUE,
        alpha = TRUE,
        wrap = FALSE
      )
  }

  p_anim <- p_anim +
    ggplot2::labs(
      title = paste0("{format(frame_time, '", label_format, "')}")
    )

  list(p_anim = p_anim, n_timesteps = n_timesteps)
}


# Internal helper: detect whether the plot contains a path or point track layer.
# Uses the track time column to skip static sf layers (e.g. colony points) that
# share a geometry type with the track layer but don't carry event timestamps.
# Returns a list(type, data) where type is "path" or "point" and data is the
# matched layer's sf data frame, or NULL if no supported layer is found.
tt_detect_layer_type <- function(p, time_col) {
  for (layer in p$layers) {
    data <- layer$data
    if (!inherits(data, "sf")) next
    if (!time_col %in% names(data)) next
    geom_types <- unique(as.character(sf::st_geometry_type(data)))
    if (all(geom_types %in% c("LINESTRING", "MULTILINESTRING"))) {
      return(list(type = "path",  data = data))
    }
    if (all(geom_types %in% c("POINT", "MULTIPOINT"))) {
      return(list(type = "point", data = data))
    }
  }
  NULL
}
