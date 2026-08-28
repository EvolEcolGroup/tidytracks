# Order a `move2` object by time within each track_id

A helper function to order a `move2` object by time within each
track_id. Note that it also reorders the track_ids. Several functions
require tracks to be ordered by time to work properly

## Usage

``` r
tt_order_time(x)
```

## Arguments

- x:

  A `move2` object

## Value

A `move2` object ordered by time

## Examples

``` r
tt_order_time(example_tt)
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
#> To see track metadata, use `show_meta()`
```
