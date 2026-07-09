# A fast function to compute distances

For unprojected longitudes and latitudes, the distance is computed as
the geodesic distance (via the `geodist` package); for projected
coordinates, the Euclidean distance is used.

## Usage

``` r
dist_fast(x1, y1, x2, y2, longlat = TRUE)
```

## Arguments

- x1:

  A vector of x coordinates

- y1:

  A vector of y coordinates

- x2:

  A vector of x coordinates

- y2:

  A vector of y coordinates

- longlat:

  Logical, if TRUE, the coordinates are assumed to be in unprojected
  longitudes and latitudes. If FALSE, the coordinates are assumed to be
  in projected coordinates.

## Value

A vector of distances
