# Clean a `move2` object using McConnell's algorithm

This function cleans a `move2` object using McConnell's algorithm. It
removes outliers based on the distance between consecutive points and
the time interval between them (more explanation; give reference TODO).
This function returns a clean `move2` object; to generate a column that
flags events to remove but does not remove them, use
[`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/reference/event_flag_mcconnell.md).

## Usage

``` r
tt_clean_mcconnell(
  x,
  max_speed = NULL,
  flag_action = c("remove", "interpolate", "null"),
  check_first_last = FALSE
)
```

## Arguments

- x:

  A move2 object

- max_speed:

  speed, provided as a `units` object (e.g. as_units(50, 'm/s').

- flag_action:

  One of "remove", "null", or "interpolate", to either remove the points
  flagged by the algorithm, keep the time stamp but set location to
  NULL, or replace the location with a linearly interpolated location
  from the events that were not filtered out.

- check_first_last:

  Logical. If `TRUE`, also evaluate the first and last currently valid
  point of each track using the endpoint RMS described above. If either
  endpoint is removed, the McConnell filter is rerun on the reduced
  track until the result is stable.

## Value

A clean `move2` object with events removed

## Examples

``` r
# this removes 3 events from the example dataset
tt_clean_mcconnell(example_tt, max_speed = as_units(50, "km/h"),
  flag_action = "remove")
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.33 hours in a
#> Simple feature collection with 12 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    track_id           date_time                geometry
#> 1         a 2024-01-01 12:00:00   POINT (1.371 -0.0627)
#> 2         a 2024-01-01 12:20:00   POINT (1.1694 3.5288)
#> 4         a 2024-01-01 13:00:00   POINT (3.6119 2.3638)
#> 5         a 2024-01-01 13:20:00  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 POINT (-2.4405 -1.7632)
#> 7         b 2024-01-01 12:20:00  POINT (-1.427 -1.9431)
#> 9         b 2024-01-01 13:00:00 POINT (-0.2703 -0.3566)
#> 10        b 2024-01-01 13:20:00 POINT (-0.9581 -1.5686)
#> 11        c 2024-01-01 12:00:00  POINT (-0.7845 0.4328)
#> 12        c 2024-01-01 12:20:00  POINT (-4.0496 1.0655)
#> To see track metadata, use `show_meta()`
```
