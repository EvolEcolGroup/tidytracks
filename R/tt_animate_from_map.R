#' Animate a user-built map with track path segments
#'
#' Takes a \code{ggplot} object built by the user and adds gganimate animation
#' so that track path segments move through time using
#' \code{\link[gganimate]{transition_time}}.
#'
#' The user first builds a complete map with all desired layers (raster
#' basemaps, polygon overlays, track data, themes, limits) and gets it looking
#' exactly right as a static plot. They then pipe it into this function to add
#' animation. Layers whose data do not contain the track datetime column (e.g.
#' a bathymetry raster or land polygons) are automatically kept static across
#' all frames by gganimate.
#'
#' The track data layer must be added with
#' \code{geom_sf(data = \link{tt_event_segments}(x), aes(...))}.
#' \code{\link{tt_event_segments}} builds one LINESTRING per step with all
#' event-table columns preserved, which is required because gganimate's
#' \code{transition_time} needs a homogeneous geometry type (the mixed
#' POINT + LINESTRING output of \code{\link{geom_event_path}} will error).
#' \code{\link{geom_track_path}} is also not suitable as it aggregates to
#' per-track metadata, discarding event timestamps.
#'
#' All aesthetic choices (colour, linewidth, alpha, etc.) are set by the user
#' in their \code{geom_sf()} call.
#'
#' @param p A \code{ggplot} object containing the fully styled map, with the
#'   track layer added using \code{geom_sf(data = tt_event_segments(x), ...)}.
#' @param x A \code{move2} object. Used to identify the datetime column name
#'   and compute the number of animation frames.
#' @param fade Logical. If \code{TRUE} (default), previous segments fade out
#'   behind the current one using \code{\link{shadow_wake_build}}. If
#'   \code{FALSE}, all previous segments remain fully visible, producing a
#'   permanently growing path using \code{\link[gganimate]{shadow_mark}}.
#' @param wake_length Numeric between 0 (exclusive) and 1 (inclusive). Length
#'   of the fading trail as a proportion of the total animation length. Only
#'   used when \code{fade = TRUE}. Default is \code{0.5}.
#' @param label_format A character string specifying the
#'   \code{\link[base]{format.POSIXct}} format for the date-time label shown on
#'   each frame. Default is \code{"\%Y-\%m-\%d \%H:\%M:\%S"}.
#'
#' @return A named list with:
#'   \describe{
#'     \item{\code{p_anim}}{A \code{gganim} object ready to pass to
#'       \code{\link[gganimate]{animate}}.}
#'     \item{\code{n_frames}}{The number of unique time steps in \code{x}.
#'       Use as the \code{nframes} argument to \code{animate()} for a
#'       one-frame-per-step animation, or multiply (e.g.
#'       \code{nframes = result$n_frames * 5}) for smoother interpolated
#'       movement between steps.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Build your map using tt_event_segments(), then pipe into tt_animate_paths()
#'
#' # Fading trail (default)
#' result <- ggplot() +
#'   geom_spatraster(data = bathy_p) +
#'   scale_fill_gradientn(colours = c("#08195e", "#85c1e9")) +
#'   geom_sf(data = tt_event_segments(df_p),
#'           aes(colour = track_id), linewidth = 1, alpha = 0.8) +
#'   scale_colour_manual(values = track_colours) +
#'   geom_spatvector(data = land_p, fill = land_colour, colour = land_colour) +
#'   theme_void() +
#'   theme(plot.background = element_rect(fill = bg_colour, colour = NA),
#'         legend.position = "none") |>
#'   tt_animate_paths(x = df_p, fade = TRUE, wake_length = 0.4,
#'                    label_format = "%Y-%m-%d %H:%M")
#'
#' # Permanently growing path
#' result <- ggplot() + ... |>
#'   tt_animate_paths(x = df_p, fade = FALSE, label_format = "%Y-%m-%d %H:%M")
#'
#' # Render: one frame per step
#' gganimate::animate(result$p_anim, nframes = result$n_frames, fps = 10,
#'                    renderer = gganimate::av_renderer())
#'
#' # Render: smoother interpolated animation
#' gganimate::animate(result$p_anim, nframes = result$n_frames * 5, fps = 25,
#'                    renderer = gganimate::av_renderer())
#' }
#'
#' @export
tt_animate_paths <- function(p,
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
  n_frames  <- length(unique(x[[time_col]]))
  time_sym  <- rlang::sym(time_col)

  p_anim <- p + gganimate::transition_time(time = !!time_sym)

  if (fade) {
    p_anim <- p_anim +
      shadow_wake_build(wake_length = wake_length,
                        size = FALSE, alpha = TRUE, wrap = FALSE)
  } else {
    p_anim <- p_anim +
      gganimate::shadow_mark(past = TRUE, future = FALSE)
  }

  p_anim <- p_anim +
    ggplot2::labs(
      title = paste0("{format(frame_time, '", label_format, "')}")
    )

  list(p_anim = p_anim, n_frames = n_frames)
}


#' Animate a user-built map with moving track points and a fading wake
#'
#' Takes a \code{ggplot} object built by the user and adds gganimate animation
#' so that track points move through time using
#' \code{\link[gganimate]{transition_time}}, with a fading wake behind each
#' point via \code{\link{shadow_wake_build}}.
#'
#' The user first builds a complete map with all desired layers and gets it
#' looking exactly right as a static plot, then pipes it into this function to
#' add animation. Layers whose data do not contain the track datetime column
#' (e.g. a bathymetry raster or land polygons) are automatically kept static
#' across all frames by gganimate.
#'
#' The track data layer in the user's plot should be added with
#' \code{\link{geom_event_point}}, which passes the \code{move2} object
#' directly to \code{geom_sf} and preserves all event-table columns including
#' the datetime column.
#'
#' All aesthetic choices (colour, size, etc.) are set by the user in their
#' \code{geom_event_point()} call.
#'
#' @param p A \code{ggplot} object containing the fully styled map, with the
#'   track layer added using \code{\link{geom_event_point}}.
#' @param x A \code{move2} object. Used to identify the datetime column name
#'   and compute the number of animation frames.
#' @param wake_length Numeric between 0 (exclusive) and 1 (inclusive). Length
#'   of the fading wake behind each point, as a proportion of the total
#'   animation length. Default is \code{0.5}.
#' @param label_format A character string specifying the
#'   \code{\link[base]{format.POSIXct}} format for the date-time label shown on
#'   each frame. Default is \code{"\%Y-\%m-\%d \%H:\%M:\%S"}.
#'
#' @return A named list with:
#'   \describe{
#'     \item{\code{p_anim}}{A \code{gganim} object ready to pass to
#'       \code{\link[gganimate]{animate}}.}
#'     \item{\code{n_frames}}{The number of unique time steps in \code{x}.
#'       Use as the \code{nframes} argument to \code{animate()} for a
#'       one-frame-per-fix animation, or multiply (e.g.
#'       \code{nframes = result$n_frames * 5}) for a smoother, tadpole-like
#'       animation where points glide between fixes with a denser wake.}
#'   }
#'
#' @examples
#' \dontrun{
#' # Build your map first, then pipe into tt_animate_points()
#' result <- ggplot() +
#'   geom_spatraster(data = bathy_p) +
#'   scale_fill_gradientn(colours = c("#08195e", "#85c1e9")) +
#'   geom_event_point(data = df_p, aes(colour = track_id), size = 5) +
#'   scale_colour_manual(values = track_colours) +
#'   geom_spatvector(data = land_p, fill = land_colour, colour = land_colour) +
#'   theme_void() +
#'   theme(plot.background = element_rect(fill = bg_colour, colour = NA),
#'         legend.position = "none") |>
#'   tt_animate_points(x = df_p, wake_length = 0.4,
#'                     label_format = "%Y-%m-%d %H:%M")
#'
#' # Render: one frame per fix
#' gganimate::animate(result$p_anim, nframes = result$n_frames, fps = 10,
#'                    renderer = gganimate::av_renderer())
#'
#' # Render: smooth tadpole animation with interpolated positions
#' gganimate::animate(result$p_anim, nframes = result$n_frames * 5, fps = 25,
#'                    renderer = gganimate::av_renderer())
#' }
#'
#' @export
tt_animate_points <- function(p,
                              x,
                              wake_length = 0.5,
                              label_format = "%Y-%m-%d %H:%M:%S") {

  if (!inherits(p, "ggplot")) {
    stop("p must be a ggplot object")
  }
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  if (!is.numeric(wake_length) || length(wake_length) != 1 ||
      wake_length <= 0 || wake_length > 1) {
    stop("wake_length must be a single numeric value greater than 0 and at most 1")
  }

  time_col <- move2::mt_time_column(x)
  n_frames  <- length(unique(x[[time_col]]))
  time_sym  <- rlang::sym(time_col)

  p_anim <- p +
    gganimate::transition_time(time = !!time_sym) +
    shadow_wake_build(
      wake_length = wake_length,
      size = TRUE,
      alpha = TRUE,
      wrap = FALSE
    ) +
    ggplot2::labs(
      title = paste0("{format(frame_time, '", label_format, "')}")
    )

  list(p_anim = p_anim, n_frames = n_frames)
}
