#' Animate tracks over time
#'
#' This function takes a tidytracks object (with a CRS defined) and creates an
#' animated visualization of the tracks over time using ggplot2 and gganimate.
#' Currently implemented only to: use the CRS defined in the tidytracks object,
#' plot on a supplied basemap, and have one frame per time step already in the
#' events data. So before running this function, you need to make sure your data
#' are in the correct CRS, your basemap is in the same CRS, and the time
#' interval between each event is regular and appropriate for you desired
#' animation. Points are automatically coloured by the field in the `move2`
#' object used as the track ID (e.g. `track_id`).
#'
#' TODO we may need to add more parameters e.g. for point size, colour palette,
#' etc. AND implement with different basemap options (e.g. terra raster). NB.
#' Timestamps must be regular AND the same (e.g. 13:00, 13:10, 13:20) for all
#' individuals so that we can have one frame per datetime - the
#' `move2::mt_interpolated()` function can be used to do this.
#'
#' The options for `type` are very important:
#' - `points`: each frame shows the current location of each animal as a point,
#' with a fading "wake" behind it to show recent movement. The locations need to
#' be frequent enough that a trail of points looks like a trailing path, at your
#' spatial scale.
#' - `paths`: each frame shows the current point, and full trajectory of each 
#' animal up to that time which does not fade.
#' 
#' 
#' @param x A `move2` object with a defined CRS.
#' @param type Either points or paths. Points = a moving animal with a fading
#'   memory; paths = a growing trajectory.
#' @param basemap An sf object to use as a basemap for the animation. If `NULL`,
#'   no basemap is used.
#' @param wake_length Numeric, length of the wake behind each point as a
#'   proportion of the total length of the animation (only for `type = "points"`).
#' @param path_alpha Numeric, the alpha to use for the path (only for 
#'   `type ="path"`).
#' @param plot_lims A numeric vector of length 4 giving the limits of the plot
#'   (`xmin`, `ymin`, `xmax`, `ymax`), default is `NULL` which uses the full
#'   extent of the data, but you may wish to add a buffer around the bounding
#'   box of `x`.
#' @param label_format A character string specifying the format of the date-time
#'  labels on the animation frames. Default is `"%Y-%m-%d %H:%M:%S"`.
#'
#' @return A `gganimate` object. To save this as a gif or video, use the
#'   function `anim_save()` from the `gganimate` package.
#' 
tt_animate <- function(x,
                       type = c("points","paths"),
                       basemap = NULL, 
                       wake_length = 0.5, # only for type = "points"
                       path_alpha = 0.5, # only for type = "paths"
                       plot_lims = NULL,
                       label_format = "%Y-%m-%d %H:%M:%S") {
 
  # check inputs
  # check x is a move2 object using inherits()
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # check that x has a defined CRS
  if (is.na(sf::st_crs(x))) {
    stop("x must have a defined CRS")
  }
  # match type argument
  type <- match.arg(type)
  # check basemap is NULL or an sf object
  if (!is.null(basemap) & !inherits(basemap, "sf")) {
    stop("basemap must be NULL or an sf object")
  }
  # check plot_lims is NULL or numeric vector of length 4
  if (!is.null(plot_lims)) {
    if (!is.numeric(plot_lims) | length(plot_lims) != 4) {
      stop("plot_lims must be NULL or a numeric vector of length 4")
    }
  }
  # if plot_lims is null, set to bounding box of x
  if (is.null(plot_lims)) {
    plot_lims <- sf::st_bbox(x)
  }
  
  # TODO the date_times are regular, but they may be slightly different for each
  # individual. Check this, and if they are different, then ask the user to
  # rediscretise the data so that, during periods of time represented in
  # multiple tracks, the date_times are shared.
  
  # ensure data are ordered by date_time within each track_id
  x <- tt_order_time(x)
  
  # extract coordinates ----
  # and set up frame id etc for plotting and animating by
  
  # track_id extracted from move2 track ID column
  # date_time extracted from move2 time column
  coords <- sf::st_coordinates(x)
  x_plot <- data.frame(track_id = x[[move2::mt_track_id_column(x)]],
                       date_time = x[[move2::mt_time_column(x)]],
                       X = coords[, 1],
                       Y = coords[, 2])
  
  # get number of frames
  n_frames <- length(unique(x$date_time))
  
  # start building plot ----
  # with layers that are relevant for both points and paths plots
  
  # if basemap is given, add to the plot
  if (!is.null(basemap)) {
    p <- ggplot2::ggplot(x_plot) +
      ggplot2::geom_sf(data = basemap, fill = "lightgrey") # TODO make basemap colour an option
  } else {
    p <- ggplot2::ggplot(x_plot)
  }
  
  # add themes and limits
  p <- p +
    ggplot2::theme_bw() +
    ggplot2::theme(legend.position = "right") +
    ggplot2::coord_sf(xlim = c(plot_lims[1], plot_lims[3]),
                      ylim = c(plot_lims[2], plot_lims[4])) +
    ggplot2::labs(x = "Longitude", y = "Latitude")
  
  # choose type
  if (type == "points") {
    
    # animate points ----
    # show current location as point, with recent locations fading behind and 
    # no explicit path.
    
    p <- p +
      ggplot2::geom_point(ggplot2::aes(x = X,y = Y,colour = track_id),
                          size = 3)
    
    # animation logic for points
    p_anim <- p +
      gganimate::transition_time(date_time) +
      # gganimate::shadow_wake(
      shadow_wake_build(
        wake_length = wake_length,
        size = TRUE,
        alpha = TRUE,
        # colour = 'grey92',
        # fill = NULL,
        # falloff = "cubic-in",
        wrap = FALSE,
        # exclude_layer = NULL,
        # exclude_phase = NULL # c("enter", "exit")
      ) +
      ggplot2::labs(
        title = paste0("{format(frame_time, '", label_format, "')}")#,
        # subtitle = "Frame {frame} of {nframes}"
        )
    
  } else if (type == "paths") {
    
    # animate paths ----
    # show current location as point, with full path up to that point, and 
    # no fading of the previous path
    
    p <- p +
      ggplot2::geom_path(ggplot2::aes(x = X, y = Y,
                                      group = track_id,
                                      colour = track_id),
                         linewidth = 1) +
      ggplot2::geom_point(ggplot2::aes(x = X, y = Y,
                                       colour = track_id),
                          size = 3)
    
    # animation logic for paths
    p_anim <- p +
      gganimate::transition_reveal(along = date_time) +
      gganimate::ease_aes("linear") +
      ggplot2::labs(
        title = paste0("{format(frame_along, '", label_format, "')}")#,
        # subtitle = "Frame {frame} of {nframes}"
      )
    
  }
  
  # return the gganimate object, the use can render it themselves
  return(list(p_anim = p_anim, n_frames = n_frames))
  
}
































