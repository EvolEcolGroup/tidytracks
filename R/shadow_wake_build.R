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
#' then size is not modified. Can also be a boolean, with `TRUE` being equal to `0`
#' and `FALSE` being equal to `NULL`
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
#' @importFrom scales alpha
#' @importFrom tweenr tween_at
#' @importFrom vctrs vec_rbind
#' @keywords internal

shadow_wake_build <- function(
  wake_length, # Proportion of total animation (0–1) to show as wake trail
  size = TRUE,
  alpha = TRUE,
  colour = NULL,
  fill = NULL,
  falloff = 'cubic-in',
  wrap = FALSE,
  exclude_layer = NULL,
  exclude_phase = c('enter', 'exit')
) {
  # Convert boolean shorthand to the numeric target values expected by tween_at:
  # TRUE  -> 0  (fade/shrink completely to nothing at the tail of the wake)
  # FALSE -> NULL (leave that aesthetic unchanged throughout the wake)
  if (is.logical(size)) size <- if (size) 0 else NULL
  if (is.logical(alpha)) alpha <- if (alpha) 0 else NULL

  # Construct a one-off ggproto instance of ShadowWakeBuild, carrying the
  # user's parameters. gganimate will call this object's methods at render time
  # to determine which past frames to include and how to style them.
  ggplot2::ggproto(
    NULL,
    ShadowWakeBuild,
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
ShadowWakeBuild <- ggplot2::ggproto(
  'ShadowWakeBuild',
  gganimate::Shadow,

  setup_params = function(self, data, params) {
    # Convert wake_length from a proportion (0–1) to an absolute
    # frame count so all downstream logic works in integer frame units.
    params$wake_length <- round(params$nframes * params$wake_length)
    params
  },

  get_frames = function(self, params, i) {
    # CUSTOM: wake grows over time
    # At frame i, only i-1 previous frames exist, so the wake is
    # shorter than wake_length until enough history has accumulated.
    n_back <- min(i - 1, params$wake_length)

    # Build a vector of past frame indices in chronological order
    # (oldest first), so prepare_shadow can apply the fade
    # from tail (index 1) to head (index n_back).
    frames <- rev(i - seq_len(n_back))

    if (params$wrap) {
      # With wrapping, frame 0 maps to the last frame of the animation,
      # so the wake "wraps around" from the end back to the beginning.
      frames <- frames %% params$nframes
      frames[frames == 0] <- params$nframes
    } else {
      # Without wrapping, discard any out-of-bounds frame indices
      # (e.g. negative frame numbers at the start of the animation).
      frames <- frames[frames > 0 & frames <= params$nframes]
    }

    frames
  },

  prepare_shadow = function(self, shadow, params) {
    # `shadow` is a list-of-lists: one inner list per layer, each
    # element of which is the rendered data for one past frame.
    # Apply falloff aesthetics to every layer independently.
    lapply(shadow, function(d) {
      if (length(d) == 0) return(NULL)

      # Build a position vector `i` in [0, 1) that encodes each
      # shadow frame's progress through the fade:
      #   0 = tail of wake (oldest, most faded)
      #   1 = head of wake (most recent, nearly full opacity)
      # Using n+1 steps and dropping the endpoint keeps the most
      # recent shadow frame near-but-not-fully opaque, matching the
      # standard shadow_wake behaviour at full length. Rescaling to
      # the actual number of available frames (n) rather than
      # params$wake_length is the key custom change: it ensures the
      # wake builds up visibly from frame 1 instead of staying nearly
      # invisible until enough history has accumulated.
      n <- length(d)
      local_at <- seq(0, 1, length.out = n + 1)[seq_len(n)]
      # Repeat each position value once per row in the corresponding
      # frame's data, so tween_at receives one value per row.
      i <- rep(local_at, vapply(d, nrow, integer(1)))

      # Stack the per-frame data frames into a single data frame for
      # vectorised tween operations below.
      d <- vctrs::vec_rbind(!!!d)

      # --- Apply colour falloff ---
      # tween_at() interpolates from params$colour (target at tail,
      # i=0) to the row's original colour (i=1) using the easing curve.
      if (!is.null(params$colour)) {
        if (!is.null(d$colour))
          d$colour <- tweenr::tween_at(
            params$colour,
            d$colour,
            i,
            params$falloff
          )
        if (!is.null(d$edge_colour))
          d$edge_colour <- tweenr::tween_at(
            params$colour,
            d$edge_colour,
            i,
            params$falloff
          )
      }

      # --- Apply fill falloff ---
      if (!is.null(params$fill)) {
        if (!is.null(d$fill))
          d$fill <- tweenr::tween_at(params$fill, d$fill, i, params$falloff)
        if (!is.null(d$edge_fill))
          d$edge_fill <- tweenr::tween_at(
            params$fill,
            d$edge_fill,
            i,
            params$falloff
          )
      }

      # --- Apply alpha falloff ---
      if (!is.null(params$alpha)) {
        # Prefer the dedicated alpha/edge_alpha column when it exists,
        # as tween_at operates on it directly.
        if (!is.null(d$edge_alpha)) {
          no_alpha <- is.na(d$edge_alpha)
          d$edge_alpha[!no_alpha] <- tweenr::tween_at(
            params$alpha,
            d$edge_alpha[!no_alpha],
            i[!no_alpha],
            params$falloff
          )
        } else if (!is.null(d$alpha)) {
          no_alpha <- is.na(d$alpha)
          d$alpha[!no_alpha] <- tweenr::tween_at(
            params$alpha,
            d$alpha[!no_alpha],
            i[!no_alpha],
            params$falloff
          )
        } else {
          # No dedicated alpha column: all rows need colour-encoded fading.
          no_alpha <- TRUE
        }

        # For rows that lack an explicit alpha column, encode the fade
        # directly into the colour/fill hex strings. We must extract the
        # current per-row alpha from the colour string rather than
        # assuming 1, because the colour may already carry a non-opaque
        # alpha channel that we need to preserve proportionally.
        i_sub <- if (isTRUE(no_alpha)) i else i[no_alpha]
        if (!is.null(d$colour)) {
          col_sub <- d$colour[no_alpha]
          cur_alpha <- grDevices::col2rgb(col_sub, alpha = TRUE)["alpha", ] /
            255
          d$colour[no_alpha] <- scales::alpha(
            col_sub,
            tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff)
          )
        }
        if (!is.null(d$fill)) {
          fill_sub <- d$fill[no_alpha]
          cur_alpha <- grDevices::col2rgb(fill_sub, alpha = TRUE)["alpha", ] /
            255
          d$fill[no_alpha] <- scales::alpha(
            fill_sub,
            tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff)
          )
        }
        if (!is.null(d$edge_colour)) {
          ec_sub <- d$edge_colour[no_alpha]
          cur_alpha <- grDevices::col2rgb(ec_sub, alpha = TRUE)["alpha", ] / 255
          d$edge_colour[no_alpha] <- scales::alpha(
            ec_sub,
            tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff)
          )
        }
        if (!is.null(d$edge_fill)) {
          ef_sub <- d$edge_fill[no_alpha]
          cur_alpha <- grDevices::col2rgb(ef_sub, alpha = TRUE)["alpha", ] / 255
          d$edge_fill[no_alpha] <- scales::alpha(
            ef_sub,
            tweenr::tween_at(params$alpha, cur_alpha, i_sub, params$falloff)
          )
        }
      }

      # --- Apply size falloff ---
      # Shrink all size-related aesthetics toward params$size at the tail.
      if (!is.null(params$size)) {
        if (!is.null(d$size))
          d$size <- tweenr::tween_at(params$size, d$size, i, params$falloff)
        if (!is.null(d$edge_size))
          d$edge_size <- tweenr::tween_at(
            params$size,
            d$edge_size,
            i,
            params$falloff
          )
        if (!is.null(d$edge_width))
          d$edge_width <- tweenr::tween_at(
            params$size,
            d$edge_width,
            i,
            params$falloff
          )
        if (!is.null(d$stroke))
          d$stroke <- tweenr::tween_at(params$size, d$stroke, i, params$falloff)
      }

      d
    })
  },

  prepare_frame_data = function(
    self,
    data,
    shadow,
    params,
    frame_ind,
    shadow_ind
  ) {
    # Combine the styled shadow data with the current frame's data for
    # each layer. Map() iterates in parallel over the per-layer lists
    # of current data (d), shadow data (s), and exclusion flags (e).
    Map(
      function(d, s, e) {
        # For excluded layers, pass the current frame's data through
        # unchanged — no shadow is added.
        if (e) return(d[[1]])

        # Only carry forward shadow rows whose IDs are present in
        # non-excluded phases of the current frame. This prevents
        # entering/exiting elements (e.g. individuals that appear or
        # disappear mid-animation) from leaving ghost trails.
        ids <- d[[1]]$.id[!d[[1]]$.phase %in% params$exclude_phase]
        s <- s[s$.id %in% ids, , drop = FALSE]

        # Prepend shadow rows (oldest first) to the current frame data.
        # gganimate renders rows in order, so the current frame's points
        # or segments are drawn on top of the wake.
        d <- vctrs::vec_rbind(s, d[[1]])

        # Reorder rows so that each group's (individual's) rows remain
        # contiguous and in their original draw order. Without this,
        # groups would be sorted shadow-first globally, which can break
        # colour grouping for multi-individual animations.
        d[order(match(d$.id, unique(d$.id))), , drop = FALSE]
      },
      d = data,
      s = shadow,
      e = seq_along(data) %in% params$excluded_layers
    )
  }
)
