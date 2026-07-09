# Measure the distance between pairs of consecutive events within each track

This function measures the distance between adjacent pairs of
consecutive events within each track. It returns a vector of distances
of the same length as the number of events in `x`, with the distance for
the last event of each track padded with an NA. For unprojected
longitudes and latitudes, the distance is computed as the geodesic
distance, which for projected coordinates, the Euclidean distance is
used.

## Usage

``` r
event_distance(x, units)
```

## Arguments

- x:

  A move2 object

- units:

  Optional, the units to use for the distance. The default is "m".

## Value

a vector of distances of the same length as the number of events in `x`,
with the last value set to NA for each track.
