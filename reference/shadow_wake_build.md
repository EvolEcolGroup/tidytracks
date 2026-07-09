# CUSTOM VERSION of Show preceding frames with gradual falloff

This shadow is meant to draw a small wake after data by showing the
latest frames up to the current. You can choose to gradually diminish
the size and/or opacity of the shadow. The length of the wake is not
given in absolute frames as that would make the animation susceptible to
changes in the framerate. Instead it is given as a proportion of the
total length of the animation. This CUSTOM VERSION is modified to build
the wake from frame 1, so that it can be used without needing to add
fake padding frames at the start of the animation. It also rescales the
fade so that the first few frames of the wake aren't super small, which
can make it more visually appealing and easier to see the motion in the
early frames. This is especially useful for animations where the motion
starts immediately and you want to show a wake from the very beginning.

## Usage

``` r
shadow_wake_build(
  wake_length,
  size = TRUE,
  alpha = TRUE,
  colour = NULL,
  fill = NULL,
  falloff = "cubic-in",
  wrap = FALSE,
  exclude_layer = NULL,
  exclude_phase = c("enter", "exit")
)
```

## Arguments

- wake_length:

  A number between 0 and 1 giving the length of the wake, in relation to
  the total number of frames.

- size:

  Numeric indicating the size the wake should end on. If `NULL` then
  size is not modified. Can also be a boolean, with `TRUE` being equal
  to `0` and `FALSE` being equal to `NULL`

- alpha:

  as `size` but for alpha modification of the wake

- colour, fill:

  colour or fill the wake should end on. If `NULL` they are not
  modified.

- falloff:

  An easing function that control how size and/or alpha should change.

- wrap:

  Should the shadow wrap around, so that the first frame will get
  shadows from the end of the animation.

- exclude_layer:

  Indexes of layers that should be excluded.

- exclude_phase:

  Element phases that should not get a shadow. Possible values are
  `'enter'`, `'exit'`, `'static'`, `'transition'`, and `'raw'`. If
  `NULL` all phases will be included. Defaults to `'enter'` and `'exit'`
