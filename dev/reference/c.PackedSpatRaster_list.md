# Combine `PackedSpatRaster_list` objects

[`c()`](https://rdrr.io/r/base/c.html) combines `PackedSpatRaster_list`
objects, and `SpatRaster` or `PackedSpatRaster` objects (wrapping them
automatically), into a single `PackedSpatRaster_list`.

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
c(...)
```

## Arguments

- ...:

  `PackedSpatRaster_list`, `SpatRaster` or `PackedSpatRaster` objects,
  or lists of them, optionally named.

## Value

A `PackedSpatRaster_list`.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- c(PackedSpatRaster_list(a = r1), PackedSpatRaster_list(b = r2))
```
