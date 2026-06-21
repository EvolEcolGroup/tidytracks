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
#'   \item{ \strong{Path layer} (`geom_event_path`): segments fade out behind
#'     the current one using a wake of length `wake_length`.}
#'   \item{ \strong{Point layer} (`geom_event_point`): points move through
#'     time with a fading, shrinking wake of length `wake_length`.}
#' }
#'
#' Setting `wake_length = 1` is a special case for both layer types: all past
#' positions are shown at full opacity with no fading, producing a permanently
#' growing path or dot trail.
#'
#' All aesthetic choices (colour, size, linewidth, alpha, etc.) are set by the
#' user in their `geom_event_path()` or `geom_event_point()` call.
#' 
#' If your animation looks very jittery, with individuals not moving smoothly,
#' it could be because the individuals do not have matching timestamps. Use 
#' \code{\link{tt_regular_time}} with `snap_times = TRUE` to ensure timestamps 
#' of all individuals match.
#'
#' @param p A `ggplot` object containing the fully styled map, with the
#'   `move2` tracking layer added using `geom_event_path` or
#'   `geom_event_point`.
#' @param layer_to_animate Optional. The `move2` object to animate over.
#'   Only needed when the map contains more than one `geom_event_path` or
#'   `geom_event_point` layer; supplying it suppresses the "multiple layers"
#'   warning and ensures the correct layer is animated. Must be the same object
#'   (by name) that was passed to `data` in the corresponding geom call.
#' @param wake_length Numeric between 0 (exclusive) and 1 (inclusive). Length
#'   of the fading trail as a proportion of the total animation length. Default
#'   is `0.5`. Set to `1` to disable fading entirely: all past positions are
#'   shown at full opacity (a permanently growing path or dot trail).
#' @param label_format A character string specifying the
#'   \code{\link[base]{format.POSIXct}} format for the date-time label shown on
#'   each frame. Default is `"\%Y-\%m-\%d \%H:\%M:\%S"`.
#'
#' @return A `gganim` object ready to pass to `gganimate::animate()`. The
#'   number of unique time steps in the track layer data is attached as
#'   `attr(result, "n_timesteps")` and can be passed directly to the `nframes`
#'   argument of `gganimate::animate()`.
#' @export
animate_map <- function(p,
                           layer_to_animate = NULL,
                           wake_length = 0.5,
                           label_format = "%Y-%m-%d %H:%M:%S") {

  layer_name <- if (!is.null(layer_to_animate)) deparse(substitute(layer_to_animate)) else NULL

  if (!inherits(p, "ggplot")) {
    stop("p must be a ggplot object")
  }
  if (!is.null(layer_to_animate) && !inherits(layer_to_animate, "move2")) {
    stop("layer_to_animate must be a move2 object")
  }
  if (!is.numeric(wake_length) || length(wake_length) != 1 ||
      wake_length <= 0 || wake_length > 1) {
    stop("wake_length must be a single numeric value greater than 0 and at most 1")
  }

  detected <- tt_detect_layer_type(p, layer_name = layer_name)

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

  if (wake_length == 1) {
    # special case: full opacity, no fading — all past positions stay visible
    p_anim <- p_anim + gganimate::shadow_mark(past = TRUE, future = FALSE)
  } else if (layer_type == "path") {
    p_anim <- p_anim +
      shadow_wake_build(wake_length = wake_length,
                        size = FALSE, alpha = TRUE, wrap = FALSE)
  } else {
    # point: fading, shrinking wake
    p_anim <- p_anim +
      shadow_wake_build(wake_length = wake_length,
                        size = TRUE, alpha = TRUE, wrap = FALSE)
  }

  p_anim <- p_anim +
    ggplot2::labs(
      title = paste0("{format(frame_time, '", label_format, "')}")
    )

  attr(p_anim, "n_timesteps") <- n_timesteps
  p_anim
}


#' Internal helper: detect whether the plot contains a path or point track layer.
#'
#' Identifies track layers exclusively by the "tidytracks_geom" attribute set on
#' their data by geom_event_path() and geom_event_point(). This prevents false
#' matches from other sf layers (e.g. land polygons) that happen to share a
#' geometry type or carry a POSIXct column.
#' If layer_name is provided (the deparsed name of the user's move2 object), only
#' layers whose "tidytracks_data_name" attribute matches are considered, allowing
#' unambiguous selection when multiple track layers are present.
#' If multiple tidytracks layers are found and layer_name is NULL, a warning is
#' issued and the first one in the plot's layer stack is used.
#'
#' @param p  the plot
#' @param layer_name name of layer
#'
#' @returns a list(type, data, time_col) where type is "path" or "point", data is
#' the matched layer's sf data frame, and time_col is the name of the POSIXct
#' column. Returns NULL if no supported layer is found.
#' @keywords internal
tt_detect_layer_type <- function(p, layer_name = NULL) {
  matches <- list()

  for (layer in p$layers) {
    # look for layers tagged with tidytracks_geom (i.e. made using
    # geom_event_point or geom_event_path).
    data <- layer$data
    tag  <- attr(data, "tidytracks_geom")
    if (is.null(tag)) next
    # get the posixct column name from the attribute set by the geom
    time_col<- attr(data, "tidytracks_time_col")
    # TODO the old code was checking if the time_col actually exists in the data
    # and is POSIXct, but this should always be true if the geoms are working
    # correctly, so maybe this check is redundant? If we want to keep it, we
    # should probably throw an error if the column is not found or not POSIXct,
    # rather than just skipping the layer silently.
    
    # # check for a datetime column
    # posixct_cols <- names(data)[vapply(data, inherits, logical(1), "POSIXct")]
    # if (length(posixct_cols) == 0L) next
    # time_col <- posixct_cols[[1L]]
 
    # add type which is either path or point depending on tidytracks_geom attr
    type <- base::switch(tag,
      event_path  = "path",
      event_point = "point",
      NULL
    )
    if (is.null(type)) next
    # add to the list of matches
    matches <- c(matches, list(list(type = type, data = data, time_col = time_col)))
  }

  if (length(matches) == 0L) return(NULL)

  # if layer_name was given, use this to filter further
  if (!is.null(layer_name)) {
    named_matches <- base::Filter(
      function(m) base::identical(attr(m$data, "tidytracks_data_name"), layer_name),
      matches
    )
    if (length(named_matches) == 0L) {
      stop(
        "No track layer with the name '", layer_name, "' was found in the map. ",
        "Check that `layer_to_animate` is the same object passed to `data` in ",
        "the geom_event_path() or geom_event_point() call.",
        call. = FALSE
      )
    }
    return(named_matches[[1L]])
  }

  # if more than 2 found (and not filtered using layer name), throw warning.
  if (length(matches) > 1L) {
    warning(
      "Multiple `move2` track layers found in the map; ",
      "animating over the first one. Use `layer_to_animate` to specify which.",
      call. = FALSE
    )
  }

  matches[[1L]]
}
