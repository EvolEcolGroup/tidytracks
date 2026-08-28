# Method to convert `trip` objects to `move2` objects

Convert `trip` objects to `move2` objects.

## Usage

``` r
# S3 method for class 'trip'
mt_as_move2(x, ...)
```

## Arguments

- x:

  A trip object

- ...:

  Additional arguments (currently ignored)

## Value

A move2 object

## Examples

``` r
mt_as_move2(trip::walrus818)
#> A <move2> with `track_id_column` "Deployment" and `time_column` "DataDT"
#> Containing 14 tracks lasting on average 36.9 days in a
#> Simple feature collection with 10558 features and 4 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -117277 ymin: -412557 xmax: 307789 ymax: 84896
#> Projected CRS: +proj=aeqd +lat_0=70 +lon_0=-170 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs
#> First 10 features:
#>    Deployment              DataDT Wet Forage             geometry
#> 1         353 2009-09-15 04:00:00   1      0 POINT (281017 22532)
#> 2         353 2009-09-15 05:00:00   0      0 POINT (281399 22392)
#> 3         353 2009-09-15 06:00:00   0      0 POINT (281209 22218)
#> 4         353 2009-09-15 07:00:00   0      0 POINT (281376 22175)
#> 5         353 2009-09-15 08:00:00   0      0 POINT (281543 22132)
#> 6         353 2009-09-15 09:00:00   0      0 POINT (281710 22089)
#> 7         353 2009-09-15 10:00:00   0      0 POINT (281877 22046)
#> 8         353 2009-09-15 11:00:00   0      0 POINT (282044 22003)
#> 9         353 2009-09-15 12:00:00   0      0 POINT (282211 21961)
#> 10        353 2009-09-15 13:00:00   0      0 POINT (282378 21918)
#> To see track metadata, use `show_meta()`
```
