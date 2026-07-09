# Compute the kde for a given group

This is the internal function that is called by `hr_kde` to compute the
kde for a given group. It is not intended to be called directly by the
user.

## Usage

``` r
kde_one_group(xy, crs, bbox, res, h, id)
```

## Arguments

- xy:

  a matrix of coordinates

- crs:

  the crs of the coordinates (to use in the geometry)

- bbox:

  A named vector of four elements: xmin, ymin, xmax, ymax to define the
  bounding box of the grid over which to compute the KDE.

- res:

  The resolution of the grid (in the units of the projection of x).

- h:

  The bandwidth for the kernel density estimation.

- id:

  The identifier for the group (used in raster metadata).

## Value

A PackedSpatRaster.
