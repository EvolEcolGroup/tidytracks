# Animate a user-built map with track paths or points

Takes a `ggplot` object built by the user, and the `tidytracks` tracking
layer plotted, and adds `gganimate` animation so that track data moves
through time.

## Usage

``` r
animate_map(
  p,
  layer_to_animate = NULL,
  wake_length = 0.5,
  label_format = "%Y-%m-%d %H:%M:%S"
)
```

## Arguments

- p:

  A `ggplot` object containing the fully styled map, with the `move2`
  tracking layer added using `geom_event_path` or `geom_event_point`.

- layer_to_animate:

  Optional. The `move2` object to animate over. Only needed when the map
  contains more than one `geom_event_path` or `geom_event_point` layer;
  supplying it suppresses the "multiple layers" warning and ensures the
  correct layer is animated. Must be the same object (by name) that was
  passed to `data` in the corresponding geom call.

- wake_length:

  Numeric between 0 (exclusive) and 1 (inclusive). Length of the fading
  trail as a proportion of the total animation length. Default is `0.5`.
  Set to `1` to disable fading entirely: all past positions are shown at
  full opacity (a permanently growing path or dot trail).

- label_format:

  A character string specifying the
  [`format.POSIXct`](https://rdrr.io/r/base/strptime.html) format for
  the date-time label shown on each frame. Default is
  `"\%Y-\%m-\%d \%H:\%M:\%S"`.

## Value

A `gganim` object ready to pass to
[`gganimate::animate()`](https://gganimate.com/reference/animate.html).
The number of unique time steps in the track layer data is attached as
`attr(result, "n_timesteps")` and can be passed directly to the
`nframes` argument of
[`gganimate::animate()`](https://gganimate.com/reference/animate.html).

## Details

The user first builds a complete map with all desired layers (e.g.
raster basemap, polygon overlays, track data, themes, limits) and gets
it looking exactly right as a static plot. They then pipe it into this
function to add animation. Layers whose data do not contain the
`track datetime` column (such as a bathymetry raster or land polygons)
are automatically kept static across all frames by gganimate.

The track data layer must be added to the `ggplot` with either
[`geom_event_path`](https://evolecolgroup.github.io/tidytracks/dev/reference/geom_event_path.md)
or
[`geom_event_point`](https://evolecolgroup.github.io/tidytracks/dev/reference/geom_event_point.md).
The function detects which is present from the geometry type in the
layer data and applies the appropriate animation:

- **Path layer** (`geom_event_path`): segments fade out behind the
  current one using a wake of length `wake_length`.

- **Point layer** (`geom_event_point`): points move through time with a
  fading, shrinking wake of length `wake_length`.

Setting `wake_length = 1` is a special case for both layer types: all
past positions are shown at full opacity with no fading, producing a
permanently growing path or dot trail.

All aesthetic choices (colour, size, linewidth, alpha, etc.) are set by
the user in their
[`geom_event_path()`](https://evolecolgroup.github.io/tidytracks/dev/reference/geom_event_path.md)
or
[`geom_event_point()`](https://evolecolgroup.github.io/tidytracks/dev/reference/geom_event_point.md)
call.

If your animation looks very jittery, with individuals not moving
smoothly, it could be because the individuals do not have matching
timestamps. Use
[`tt_regular_time`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_regular_time.md)
with `snap_times = TRUE` to ensure timestamps of all individuals match.

## Examples

``` r
# Create a map using example_tt dataset (print map if you want to check it)
library(ggplot2)
map <- ggplot() +
  geom_event_path(data = example_tt, aes(colour = track_id), 
                  size = 2, lineend = "round")
# Add animation logic
map_anim <- animate_map(p = map, wake_length = 1)
# This is a gganim object
class(map_anim)
#> [1] "gganim"          "ggplot2::ggplot" "ggplot"          "ggplot2::gg"    
#> [5] "S7_object"       "gg"             
# \donttest{
# Render the animation - this can take a while on real datasets
gganimate::animate(plot = map_anim,
                  nframes = attr(map_anim, "n_timesteps"),
                  duration = 2 # video duration in seconds
)
#> # A tibble: 4 × 7
#>   format width height colorspace matte filesize density
#>   <chr>  <int>  <int> <chr>      <lgl>    <int> <chr>  
#> 1 gif      480    480 sRGB       FALSE        0 72x72  
#> 2 gif      480    480 sRGB       TRUE         0 72x72  
#> 3 gif      480    480 sRGB       TRUE         0 72x72  
#> 4 gif      480    480 sRGB       TRUE         0 72x72  
# }
```
