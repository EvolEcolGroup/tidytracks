# Thin tracks to a time interval

This function keeps, within each track, the largest subset of events
such that consecutive kept events are separated by `interval` (plus or
minus `tolerance`), and removes the other events. Unlike
[`tt_regular_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_regular_time.md),
which interpolates new locations on a regular time grid, this keeps a
subset of the original events. It is a wrapper around
[`move2utils::mt_thin_time()`](https://move2universe.github.io/move2utils/reference/mt_thin_time.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`). See
[`event_flag_thin_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_thin_time.md)
for details, and to flag the events to keep without removing the others.

## Usage

``` r
tt_thin_time(x, interval, tolerance = NULL, criterion = c("closest", "first"))
```

## Arguments

- x:

  A `move2` object.

- interval:

  The target time interval between consecutive kept events, as a `units`
  object (e.g. `as_units(1, "h")`).

- tolerance:

  The accepted deviation from `interval`, as a `units` object with time
  units. Defaults to `interval / 10`.

- criterion:

  How to choose among subsets with the same number of events: "closest"
  (the default) keeps the subset whose intervals deviate least from
  `interval` in total, "first" keeps the subset that starts earliest.

## Value

The `move2` object `x` with only the kept events.

## Examples

``` r
# keep events 40 minutes apart (events in example_tt are 20 minutes apart)
tt_thin_time(example_tt, interval = as_units(40, "min"))
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.33 hours in a
#> Simple feature collection with 9 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.7632 xmax: 5.5357 ymax: 3.0464
#> Geodetic CRS:  WGS 84
#>    track_id           date_time                geometry
#> 1         a 2024-01-01 12:00:00   POINT (1.371 -0.0627)
#> 3         a 2024-01-01 12:40:00   POINT (2.2065 1.8612)
#> 5         a 2024-01-01 13:20:00  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 POINT (-2.4405 -1.7632)
#> 8         b 2024-01-01 12:40:00 POINT (-3.3802 -0.7828)
#> 10        b 2024-01-01 13:20:00 POINT (-0.9581 -1.5686)
#> 11        c 2024-01-01 12:00:00  POINT (-0.7845 0.4328)
#> 13        c 2024-01-01 12:40:00  POINT (-3.8075 1.2897)
#> 15        c 2024-01-01 13:20:00  POINT (-5.5053 3.0464)
#> Track features:
#>   track_id    sex nest_lon nest_lat
#> 1        a   male     1.37     0.06
#> 2        b   male    -2.44    -1.76
#> 3        c female    -0.78     0.43
```
