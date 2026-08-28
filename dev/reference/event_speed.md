# Return the speed of each segment between events

This function returns the speed of each segment between events for each
track. In order to return a vector with the same number of rows as the
event table, the speed of the last event is set to NA. The speed is
calculated as the distance between events divided by the time between
events.

## Usage

``` r
event_speed(x, units = as_units("m/min"))
```

## Arguments

- x:

  A move2 object

- units:

  Optional units to use for speed. The default is `"m/min"`. Other speed
  units supported by the `units` package can also be supplied.

## Value

a vector of speeds of the same length as the number of events in `x`,
with the last value set to NA for each track.

## Details

For unprojected longitudes and latitudes, the distance is computed as
the geodesic distance (via the `geodist` package); for projected
coordinates, the Euclidean distance is used.

## Examples

``` r
event_speed(example_tt)
#> Units: [m/min]
#>  [1] 19888.264 10874.390  8296.315 19466.359        NA  5725.241 12620.243
#>  [8] 17468.389  7716.999        NA 18505.445  1830.715  3377.495 16919.212
#> [15]        NA
event_speed(example_tt, units = as_units("m/s"))
#> Units: [m/s]
#>  [1] 331.47106 181.23984 138.27192 324.43932        NA  95.42068 210.33738
#>  [8] 291.13982 128.61666        NA 308.42409  30.51192  56.29158 281.98687
#> [15]        NA
```
