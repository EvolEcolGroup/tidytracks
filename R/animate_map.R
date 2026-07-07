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

  # Capture the name of the move2 object as a string at call time, before any
  # evaluation. This is used later to match against the "tidytracks_data_name"
  # attribute stamped on layer data by the geoms, allowing unambiguous selection
  # when multiple track layers are present.
  layer_name <- if (!is.null(layer_to_animate)) deparse(substitute(layer_to_animate)) else NULL

  # --- Input validation ---
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

  # --- Detect the track layer to animate ---
  # Scan the plot's layer stack for a layer tagged by geom_event_path or
  # geom_event_point. Returns a list(type, data, time_col), or NULL if none found.
  detected <- tt_detect_layer_type(p, layer_name = layer_name)

  if (is.null(detected)) {
    stop(
      "No supported track layer found. ",
      "Add a geom_event_path() or geom_event_point() layer to the plot."
    )
  }

  # Pull the time column name and geometry type ("path" or "point") from the
  # detection result.
  time_col <- detected$time_col

  layer_type <- detected$type
  # Derive n_timesteps from the layer data itself: for path layers the final event
  # of each track is dropped by geom_event_path, so the layer may contain fewer
  # unique timestamps than x.
  n_timesteps <- length(unique(detected$data[[time_col]]))
  # Convert the column name string to a symbol so it can be unquoted inside
  # the transition_time() call with !!.
  time_sym  <- rlang::sym(time_col)

  # --- Build the animated plot ---
  # transition_time() drives the animation: gganimate renders one frame per
  # unique value of the time column, interpolating between them.
  p_anim <- p + gganimate::transition_time(time = !!time_sym)

  # --- Add the appropriate wake / shadow layer ---
  if (wake_length == 1) {
    # Special case: retain all past positions at full opacity with no fading.
    # shadow_mark() is used here instead of shadow_wake() because it preserves
    # every previously rendered frame permanently without any falloff.
    p_anim <- p_anim + gganimate::shadow_mark(past = TRUE, future = FALSE)
  } else if (layer_type == "path") {
    # Path wake: alpha fades out along the trail, but size stays constant —
    # shrinking line width looks odd for segment-based paths.
    p_anim <- p_anim +
      shadow_wake_build(wake_length = wake_length,
                        size = FALSE, alpha = TRUE, wrap = FALSE)
  } else {
    # Point wake: both alpha and size shrink along the trail, giving a comet-
    # like effect that clearly shows direction of travel.
    p_anim <- p_anim +
      shadow_wake_build(wake_length = wake_length,
                        size = TRUE, alpha = TRUE, wrap = FALSE)
  }

  # --- Add a dynamic frame-time label to the plot title ---
  # gganimate evaluates the title string as a glue expression, so wrapping the
  # format() call in {} causes it to be re-evaluated and updated on every frame.
  p_anim <- p_anim +
    ggplot2::labs(
      title = paste0("{format(frame_time, '", label_format, "')}")
    )

  # Attach the frame count as an attribute so callers can pass it directly to
  # the `nframes` argument of gganimate::animate() without having to recount.
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

  # Iterate over every layer in the plot, looking for ones tagged by tidytracks.
  for (layer in p$layers) {
    # Only geom_event_path and geom_event_point set the "tidytracks_geom"
    # attribute on their data; all other layers (basemaps, polygons, etc.)
    # won't have it and are skipped.
    data <- layer$data
    tag  <- attr(data, "tidytracks_geom")
    if (is.null(tag)) next
    # The geom also stamps the name of the time column on the data, saving us
    # from having to guess which POSIXct column to animate over.
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
 
    # Map the raw tag string to the canonical type label used downstream.
    type <- base::switch(tag,
      event_path  = "path",
      event_point = "point",
      NULL
    )
    if (is.null(type)) next
    # Collect all valid matches; we may need to disambiguate below.
    matches <- c(matches, list(list(type = type, data = data, time_col = time_col)))
  }

  if (length(matches) == 0L) return(NULL)

  # If the caller named a specific move2 object to animate, filter the candidate
  # list down to only layers whose data carry a matching "tidytracks_data_name"
  # attribute. This is the mechanism that prevents ambiguity when the map has
  # more than one track layer.
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

  # If multiple tidytracks layers exist and no name was given, warn and fall
  # back to the first one (i.e. the lowest layer in the plot stack).
  if (length(matches) > 1L) {
    warning(
      "Multiple `move2` track layers found in the map; ",
      "animating over the first one. Use `layer_to_animate` to specify which.",
      call. = FALSE
    )
  }

  matches[[1L]]
}
