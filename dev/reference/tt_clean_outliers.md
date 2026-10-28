# Clean a `move2` object using the outlier methods of move2utils

This function detects outlying locations with one of the methods of the
package `move2utils` (see
[`event_flag_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_outliers.md)
for the methods), and removes them, sets their location to empty, or
replaces their location by interpolation. It requires the suggested
package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`). To flag the
outliers without acting on them, use
[`event_flag_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_outliers.md).

## Usage

``` r
tt_clean_outliers(
  x,
  method = c("clean_track", "speed_cap", "detour", "bridge", "probability"),
  ...,
  flag_action = c("remove", "interpolate", "null")
)
```

## Arguments

- x:

  A `move2` object.

- method:

  The method used to detect outliers, one of "clean_track" (the
  default), "speed_cap", "detour", "bridge" or "probability" (see
  Details).

- ...:

  Further arguments passed to the `move2utils` function of the chosen
  method.

- flag_action:

  One of "remove", "null", or "interpolate", to either remove the
  outliers, keep their time stamp but set their location to NULL, or
  replace their location with a linearly interpolated location from the
  events that are not outliers.

## Value

The `move2` object `x`, with the outliers acted on.

## Examples

``` r
tt_clean_outliers(example_tt, method = "detour")
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.33 hours in a
#> Simple feature collection with 15 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    track_id           date_time                geometry
#> 1         a 2024-01-01 12:00:00   POINT (1.371 -0.0627)
#> 2         a 2024-01-01 12:20:00   POINT (1.1694 3.5288)
#> 3         a 2024-01-01 12:40:00   POINT (2.2065 1.8612)
#> 4         a 2024-01-01 13:00:00   POINT (3.6119 2.3638)
#> 5         a 2024-01-01 13:20:00  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 POINT (-2.4405 -1.7632)
#> 7         b 2024-01-01 12:20:00  POINT (-1.427 -1.9431)
#> 8         b 2024-01-01 12:40:00 POINT (-3.3802 -0.7828)
#> 9         b 2024-01-01 13:00:00 POINT (-0.2703 -0.3566)
#> 10        b 2024-01-01 13:20:00 POINT (-0.9581 -1.5686)
#> Track features:
#>   track_id    sex nest_lon nest_lat
#> 1        a   male     1.37     0.06
#> 2        b   male    -2.44    -1.76
#> 3        c female    -0.78     0.43
```
