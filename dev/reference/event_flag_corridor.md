# Flag the steps that are part of movement corridors

This function detects corridors: places where animals move fast, in a
consistent direction (either way along the corridor). It is a wrapper
around
[`move2utils::mt_corridor()`](https://move2universe.github.io/move2utils/reference/mt_corridor.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
event_flag_corridor(
  x,
  speed_threshold = NULL,
  circvar_threshold = NULL,
  min_segments = 2
)
```

## Arguments

- x:

  A `move2` object.

- speed_threshold:

  The speed at or above which a step is fast, as a `units` object (e.g.
  `as_units(1, "m/s")`). Defaults to the upper quartile of the speeds of
  the steps.

- circvar_threshold:

  A number between 0 and 1: the circular variance of the directions of
  the nearby steps at or below which they are considered to run in a
  similar direction. Defaults to the lower quartile of the circular
  variances.

- min_segments:

  The minimum number of nearby steps (including the step itself) for a
  step to be part of a corridor.

## Value

A logical vector with one value per event of `x`, `TRUE` for the events
whose next step is part of a corridor (the last event of each track is
`FALSE`).

## Details

The nearby steps of a step (from an event to the next one in the same
track) are the steps whose midpoints are within half its length of its
midpoint, including the step itself. A step is a candidate if it is fast
(`speed_threshold`), and if its nearby steps run in a similar direction
(`circvar_threshold`). A step is then flagged as part of a corridor if
it has at least `min_segments` nearby steps, and if more than half of
them are candidates; a step that is not a candidate itself (e.g. a slow
step) can therefore be flagged when it lies within a corridor.

When `speed_threshold` or `circvar_threshold` are not given, they are
estimated from all the steps in `x` (pooling all tracks), with a warning
giving the value used; give explicit values to compare corridors among
datasets.

The search radius depends on the length of the steps, so it assumes
roughly regular sampling; `move2utils` warns when the time intervals are
very irregular.

`x` must be ordered by time within each track (see
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)).
Events without a location are ignored, and get `NA`.

## References

Based on the `corridor()` function of the `move` package, see LaPoint,
S., Gallery, P., Wikelski, M. & Kays, R. (2013). Animal behavior,
cost-based corridor models, and real corridors. *Landscape Ecology*, 28,
1615-1630.
[doi:10.1007/s10980-013-9910-0](https://doi.org/10.1007/s10980-013-9910-0)

## Examples

``` r
event_flag_corridor(
  example_tt,
  speed_threshold = as_units(5, "m/s"),
  circvar_threshold = 0.5,
  min_segments = 1
)
#>  [1] FALSE FALSE FALSE FALSE FALSE FALSE  TRUE FALSE FALSE FALSE FALSE FALSE
#> [13] FALSE FALSE FALSE
```
