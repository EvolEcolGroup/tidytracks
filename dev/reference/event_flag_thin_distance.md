# Flag events to keep when thinning tracks by distance travelled

This function selects, within each track, events spaced by the distance
travelled along the track. It is a wrapper around
[`move2utils::mt_thin_distance()`](https://move2universe.github.io/move2utils/reference/mt_thin_distance.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
event_flag_thin_distance(
  x,
  distance,
  tolerance = NULL,
  method = c("step", "interval"),
  criterion = c("closest", "first")
)
```

## Arguments

- x:

  A `move2` object.

- distance:

  The target distance travelled between consecutive kept events, as a
  `units` object (e.g. `as_units(500, "m")`).

- tolerance:

  Only used with `method = "interval"`: the accepted deviation from
  `distance`, as a `units` object with length units. Defaults to
  `distance / 10`.

- method:

  The thinning method, either "step" (the default) or "interval" (see
  Details).

- criterion:

  Only used with `method = "interval"`: how to choose among subsets with
  the same number of events. "closest" (the default) keeps the subset
  whose distances deviate least from `distance` in total, "first" keeps
  the subset that starts earliest.

## Value

A logical vector with one value per event of `x`, `TRUE` for the events
to keep.

## Details

Two methods are available:

- `method = "step"` (the default) keeps the first event of each track,
  and then the first event at which the distance travelled since the
  last kept event reaches `distance`. Consecutive kept events are
  therefore at least `distance` apart along the track (and can be
  further apart, as no new locations are interpolated).

- `method = "interval"` keeps the largest subset of events such that the
  distance travelled between consecutive kept events is `distance` (plus
  or minus `tolerance`); it is the equivalent of
  [`event_flag_thin_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_thin_time.md)
  for distances. Tracks are split at any step longer than
  `distance + tolerance`, and the first event is not necessarily kept.

Distances are great-circle distances for longitude/latitude coordinates,
and planar distances for projected coordinates. Events without a
location are ignored when measuring distances, and are never kept. `x`
must be ordered by time within each track (see
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)).
To remove the events that are not kept, use
[`tt_thin_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_thin_distance.md).

## Examples

``` r
# keep events at least 200 km apart along each track
event_flag_thin_distance(example_tt, distance = as_units(200, "km"))
#>  [1]  TRUE  TRUE  TRUE FALSE  TRUE  TRUE FALSE  TRUE  TRUE FALSE  TRUE  TRUE
#> [13] FALSE FALSE  TRUE
```
