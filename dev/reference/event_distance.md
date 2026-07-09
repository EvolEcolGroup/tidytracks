# Measure the distance between pairs of consecutive events within each track

This function returns the distance of each segment between events for
each track. In order to return a vector with the same number of rows as
the event table, the distance of the last event is set to NA.

## Usage

``` r
event_distance(x, units = as_units("m"))
```

## Arguments

- x:

  A move2 object.

- units:

  Optional, the units to use for the distance. The default is "m". '
  Other distance units supported by the `units` package can also be
  supplied.

## Value

A vector of distances of the same length as the number of events in `x`,
with the last value set to NA for each track.

## Details

For unprojected longitudes and latitudes, the distance is computed as
the geodesic distance (via the `geodist` package); for projected
coordinates, the Euclidean distance is used.

## Examples

``` r
event_distance(example_tt)
#> Units: [m]
#>  [1] 397765.28 217487.80 165926.30 389327.19        NA 114504.81 252404.85
#>  [8] 349367.79 154339.99        NA 370108.91  36614.31  67549.89 338384.25
#> [15]        NA
event_distance(example_tt, units = as_units("km"))
#> Units: [km]
#>  [1] 397.76528 217.48780 165.92630 389.32719        NA 114.50481 252.40485
#>  [8] 349.36779 154.33999        NA 370.10891  36.61431  67.54989 338.38425
#> [15]        NA
```
