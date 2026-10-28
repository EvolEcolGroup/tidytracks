# Thin tracks by distance travelled

This function keeps, within each track, events spaced by the distance
travelled along the track, and removes the other events. It is a wrapper
around
[`move2utils::mt_thin_distance()`](https://move2universe.github.io/move2utils/reference/mt_thin_distance.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`). See
[`event_flag_thin_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_thin_distance.md)
for details of the methods, and to flag the events to keep without
removing the others.

## Usage

``` r
tt_thin_distance(
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

The `move2` object `x` with only the kept events.

## Examples

``` r
# keep events at least 200 km apart along each track
tt_thin_distance(example_tt, distance = as_units(200, "km"))
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.22 hours in a
#> Simple feature collection with 10 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.7632 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#>    track_id           date_time                geometry
#> 1         a 2024-01-01 12:00:00   POINT (1.371 -0.0627)
#> 2         a 2024-01-01 12:20:00   POINT (1.1694 3.5288)
#> 3         a 2024-01-01 12:40:00   POINT (2.2065 1.8612)
#> 5         a 2024-01-01 13:20:00  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 POINT (-2.4405 -1.7632)
#> 8         b 2024-01-01 12:40:00 POINT (-3.3802 -0.7828)
#> 9         b 2024-01-01 13:00:00 POINT (-0.2703 -0.3566)
#> 11        c 2024-01-01 12:00:00  POINT (-0.7845 0.4328)
#> 12        c 2024-01-01 12:20:00  POINT (-4.0496 1.0655)
#> 15        c 2024-01-01 13:20:00  POINT (-5.5053 3.0464)
#> Track features:
#>   track_id    sex nest_lon nest_lat
#> 1        a   male     1.37     0.06
#> 2        b   male    -2.44    -1.76
#> 3        c female    -0.78     0.43
```
