#' Animate a user-built map with track paths or points
#'
#' Takes a `ggplot` object built by the user, and the `tidytracks` tracking
#' layer plotted, and adds `gganimate` animation so that track data moves
#' through time.
#'
#' The user first builds a complete map with all desired layers (e.g. raster
#' basemap, polygon overlays, track data, themes, limits) and gets it looking
#' exactly right as a static plot. They then pipe it into this function to add
#' animation. Layers whose data do not contain the `track datetime` column (such
#' as a bathymetry raster or land polygons) are automatically kept static across
#' all frames by gganimate.
#'
#' The track data layer must be added to the `ggplot` with either
#' \code{\link{geom_event_path}} or \code{\link{geom_event_point}}. The function
#' detects which is present from the geometry type in the layer data and applies
#' the appropriate animation:
#'
#' \itemize{
#'   \item{ \strong{Path layer} (`geom_event_path`): if `fade = TRUE`,
#'     segments fade out behind the current one; if `fade = FALSE`, all
#'     previous segments remain visible, producing a permanently growing path.}
#'   \item{ \strong{Point layer} (`geom_event_point`): points move through
#'     time with a fading, shrinking wake regardless of `fade`.}
#' }
#'
#' All aesthetic choices (colour, size, linewidth, alpha, etc.) are set by the
#' user in their `geom_event_path()` or `geom_event_point()` call.
#'
#' @param p A `ggplot` object containing the fully styled map, with the
#'   `move2` tracking layer added using `geom_event_path` or
#'   `geom_event_point`.
#' @param fade Logical. Only relevant for path animations. If `TRUE`
#'   (default), previous segments fade out behind the current one using
#'   `shadow_wake_build`. If `FALSE`, all previous segments
#'   remain fully visible, producing a permanently growing path.
#' @param wake_length Numeric between 0 (exclusive) and 1 (inclusive). Length
#'   of the fading trail as a proportion of the total animation length. Only
#'   used when `fade = TRUE` (paths) or for point animations. Default is
#'   `0.5`.
#' @param label_format A character string specifying the
#'   \code{\link[base]{format.POSIXct}} format for the date-time label shown on
#'   each frame. Default is `"\%Y-\%m-\%d \%H:\%M:\%S"`.
#'
#' @return A named list with: `p_anim` (a `gganim` object ready to pass to
#'   `gganimate::animate()`) and `n_timesteps` (the number of unique time steps
#'   in the layer data).
#' @export
animate_map <- function(p,
                           fade = TRUE,
                           wake_length = 0.5,
                           label_format = "%Y-%m-%d %H:%M:%S") {

  if (!inherits(p, "ggplot")) {
    stop("p must be a ggplot object")
  }
  if (!is.logical(fade) || length(fade) != 1 || is.na(fade)) {
    stop("fade must be TRUE or FALSE")
  }
  if (!is.numeric(wake_length) || length(wake_length) != 1 ||
      wake_length <= 0 || wake_length > 1) {
    stop("wake_length must be a single numeric value greater than 0 and at most 1")
  }

  detected <- tt_detect_layer_type(p)

  if (is.null(detected)) {
    stop(
      "No supported track layer found. ",
      "Add a geom_event_path() or geom_event_point() layer to the plot."
    )
  }

  time_col <- detected$time_col

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
# Identifies track layers exclusively by the "tidytracks_geom" attribute set on
# their data by geom_event_path() and geom_event_point(). This prevents false
# matches from other sf layers (e.g. land polygons) that happen to share a
# geometry type or carry a POSIXct column.
# If multiple tidytracks layers are found, a warning is issued and the first one
# in the plot's layer stack is used.
# Returns a list(type, data, time_col) where type is "path" or "point", data is
# the matched layer's sf data frame, and time_col is the name of the POSIXct
# column. Returns NULL if no supported layer is found.
tt_detect_layer_type <- function(p) {
  matches <- list()

  for (layer in p$layers) {
    data <- layer$data
    tag  <- attr(data, "tidytracks_geom")
    if (is.null(tag)) next

    posixct_cols <- names(data)[vapply(data, inherits, logical(1), "POSIXct")]
    if (length(posixct_cols) == 0L) next
    time_col <- posixct_cols[[1L]]

    type <- switch(tag,
      event_path  = "path",
      event_point = "point",
      NULL
    )
    if (is.null(type)) next

    matches <- c(matches, list(list(type = type, data = data, time_col = time_col)))
  }

  if (length(matches) == 0L) return(NULL)

  if (length(matches) > 1L) {
    warning(
      "Multiple `move2` track layers found in the map; ",
      "animating over the first one.",
      call. = FALSE
    )
  }

  matches[[1L]]
}
