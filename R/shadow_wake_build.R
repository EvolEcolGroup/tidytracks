#' CUSTOM VERSION of Show preceding frames with gradual falloff
#'
#' This shadow is meant to draw a small wake after data by showing the latest
#' frames up to the current. You can choose to gradually diminish the size
#' and/or opacity of the shadow. The length of the wake is not given in absolute
#' frames as that would make the animation susceptible to changes in the
#' framerate. Instead it is given as a proportion of the total length of the
#' animation. This CUSTOM VERSION is modified to build the wake from frame 1, so
#' that it can be used without needing to add fake padding frames at the start
#' of the animation. It also rescales the fade so that the first few frames of
#' the wake aren't super small, which can make it more visually appealing and
#' easier to see the motion in the early frames. This is especially useful for
#' animations where the motion starts immediately and you want to show a wake
#' from the very beginning.
#' 
#'
#' @param wake_length A number between 0 and 1 giving the length of the wake,
#' in relation to the total number of frames.
#' @param size Numeric indicating the size the wake should end on. If `NULL`
#' then size is not modified. Can also be a boolean with `TRUE` beeing equal `0`
#' and `FALSE` beeing equal to `NULL`
#' @param alpha as `size` but for alpha modification of the wake
#' @param colour,fill colour or fill the wake should end on. If `NULL` they are
#' not modified.
#' @param falloff An easing function that control how size and/or alpha should
#' change.
#' @param wrap Should the shadow wrap around, so that the first frame will get
#' shadows from the end of the animation.
#' @param exclude_layer Indexes of layers that should be excluded.
#' @param exclude_phase Element phases that should not get a shadow. Possible
#' values are `'enter'`, `'exit'`, `'static'`, `'transition'`, and `'raw'`. If
#' `NULL` all phases will be included. Defaults to `'enter'` and `'exit'`
#'
#' @family shadows
#'
#' @importFrom ggplot2 ggproto
#' @keywords internal
#'
#' @examples
#' anim <- ggplot(iris, aes(Petal.Length, Sepal.Length)) +
#'   geom_point() +
#'   labs(title = "{closest_state}") +
#'   transition_states(Species, transition_length = 4, state_length = 1)
#'
#' # `shadow_wake` can be combined with e.g. `transition_states` to show
#' # motion of geoms as they are in transition with respect to the selected state.
#' anim1 <- anim +
#'   shadow_wake(wake_length = 0.05)
#'
#' # Different qualities can be manipulated by setting a value for it that it
#' # should taper off to
#' anim2 <- anim +
#'   shadow_wake(0.1, size = 10, alpha = FALSE, colour = 'grey92')
#'
#' # Use `detail` in the `animate()` call to increase the number of calculated
#' # frames and thus make the wake smoother
#' \dontrun{
#' animate(anim2, detail = 5)
#' }
#'

shadow_wake_build <- function(wake_length,
                              size = TRUE,
                              alpha = TRUE,
                              colour = NULL,
                              fill = NULL,
                              falloff = 'cubic-in',
                              wrap = FALSE,
                              exclude_layer = NULL,
                              exclude_phase = c('enter', 'exit')) {
  
  if (is.logical(size)) size <- if (size) 0 else NULL
  if (is.logical(alpha)) alpha <- if (alpha) 0 else NULL
  
  ggplot2::ggproto(NULL, ShadowWakeBuild,
                   exclude_layer = exclude_layer,
                   params = list(
                     wake_length = wake_length,
                     colour = colour,
                     fill = fill,
                     size = size,
                     alpha = alpha,
                     falloff = falloff,
                     wrap = wrap,
                     exclude_phase = exclude_phase
                   )
  )
}

# modified ggproto to go with the new shadow wake
ShadowWakeBuild <- ggplot2::ggproto('ShadowWakeBuild', gganimate::Shadow,
                                    
                                    setup_params = function(self, data, params) {
                                      params$wake_length <- round(params$nframes * params$wake_length)
                                      params
                                    },
                                    
                                    get_frames = function(self, params, i) {
                                      # CUSTOM: wake grows over time
                                      n_back <- min(i - 1, params$wake_length)
                                      
                                      frames <- rev(i - seq_len(n_back))
                                      
                                      if (params$wrap) {
                                        frames <- frames %% params$nframes
                                        frames[frames == 0] <- params$nframes
                                      } else {
                                        frames <- frames[frames > 0 & frames <= params$nframes]
                                      }
                                      
                                      frames
                                    },
                                    
                                    prepare_shadow = function(self, shadow, params) {
                                      lapply(shadow, function(d) {
                                        if (length(d) == 0) return(NULL)
                                        
                                        # CUSTOM: rescale fade to the actual number of available shadow
                                        # frames, so the wake builds up properly from the start rather
                                        # than staying invisible until enough frames have elapsed.
                                        # Use n+1 steps and drop the endpoint so the most recent shadow
                                        # frame is close-to-but-not-fully opaque (matching the original
                                        # shadow_wake behaviour at full length).
                                        n <- length(d)
                                        local_at <- seq(0, 1, length.out = n + 1)[seq_len(n)]
                                        i <- rep(local_at, vapply(d, nrow, integer(1)))
                                        
                                        d <- vctrs::vec_rbind(!!!d)
                                        
                                        if (!is.null(params$colour)) {
                                          if (!is.null(d$colour)) d$colour <- tweenr::tween_at(params$colour, d$colour, i, params$falloff)
                                          if (!is.null(d$edge_colour)) d$edge_colour <- tweenr::tween_at(params$colour, d$edge_colour, i, params$falloff)
                                        }
                                        
                                        if (!is.null(params$fill)) {
                                          if (!is.null(d$fill)) d$fill <- tweenr::tween_at(params$fill, d$fill, i, params$falloff)
                                          if (!is.null(d$edge_fill)) d$edge_fill <- tweenr::tween_at(params$fill, d$edge_fill, i, params$falloff)
                                        }
                                        
                                        if (!is.null(params$alpha)) {
                                          if (!is.null(d$edge_alpha)) {
                                            no_alpha <- is.na(d$edge_alpha)
                                            d$edge_alpha[!no_alpha] <- tweenr::tween_at(params$alpha, d$edge_alpha[!no_alpha], i[!no_alpha], params$falloff)
                                          } else if (!is.null(d$alpha)) {
                                            no_alpha <- is.na(d$alpha)
                                            d$alpha[!no_alpha] <- tweenr::tween_at(params$alpha, d$alpha[!no_alpha], i[!no_alpha], params$falloff)
                                          } else {
                                            no_alpha <- TRUE
                                          }
                                          
                                          # For rows without an explicit alpha column, fade is encoded
                                          # directly in the colour/fill strings. tween_at requires b to be
                                          # the same length as at, so we extract the per-row current alpha
                                          # rather than passing the scalar 1.
                                          i_sub <- if (isTRUE(no_alpha)) i else i[no_alpha]
                                          if (!is.null(d$colour)) {
                                            col_sub <- d$colour[no_alpha]
                                            cur_alpha <- grDevices::col2rgb(col_sub, alpha = TRUE)["alpha", ] / 255
                                            d$colour[no_alpha] <- scales::alpha(col_sub, tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff))
                                          }
                                          if (!is.null(d$fill)) {
                                            fill_sub <- d$fill[no_alpha]
                                            cur_alpha <- grDevices::col2rgb(fill_sub, alpha = TRUE)["alpha", ] / 255
                                            d$fill[no_alpha] <- scales::alpha(fill_sub, tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff))
                                          }
                                          if (!is.null(d$edge_colour)) {
                                            ec_sub <- d$edge_colour[no_alpha]
                                            cur_alpha <- grDevices::col2rgb(ec_sub, alpha = TRUE)["alpha", ] / 255
                                            d$edge_colour[no_alpha] <- scales::alpha(ec_sub, tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff))
                                          }
                                          if (!is.null(d$edge_fill)) {
                                            ef_sub <- d$edge_fill[no_alpha]
                                            cur_alpha <- grDevices::col2rgb(ef_sub, alpha = TRUE)["alpha", ] / 255
                                            d$edge_fill[no_alpha] <- scales::alpha(ef_sub, tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff))
                                          }
                                        }
                                        
                                        if (!is.null(params$size)) {
                                          if (!is.null(d$size)) d$size <- tweenr::tween_at(params$size, d$size, i, params$falloff)
                                          if (!is.null(d$edge_size)) d$edge_size <- tweenr::tween_at(params$size, d$edge_size, i, params$falloff)
                                          if (!is.null(d$edge_width)) d$edge_width <- tweenr::tween_at(params$size, d$edge_width, i, params$falloff)
                                          if (!is.null(d$stroke)) d$stroke <- tweenr::tween_at(params$size, d$stroke, i, params$falloff)
                                        }
                                        
                                        d
                                      })
                                    },
                                    
                                    prepare_frame_data = function(self, data, shadow, params, frame_ind, shadow_ind) {
                                      Map(function(d, s, e) {
                                        if (e) return(d[[1]])
                                        
                                        ids <- d[[1]]$.id[!d[[1]]$.phase %in% params$exclude_phase]
                                        s <- s[s$.id %in% ids, , drop = FALSE]
                                        
                                        d <- vctrs::vec_rbind(s, d[[1]])
                                        
                                        d[order(match(d$.id, unique(d$.id))), , drop = FALSE]
                                      }, d = data, s = shadow, e = seq_along(data) %in% params$excluded_layers)
                                    }
)