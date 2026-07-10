# Create a `PackedSpatRaster_list`

Accepts `SpatRaster` objects (packed automatically) or already-packed
objects. A lightweight S3 class wrapping a named or unnamed list of
`PackedSpatRaster`

## Usage

``` r
PackedSpatRaster_list(...)
```

## Arguments

- ...:

  `SpatRaster` / `PackedSpatRaster` objects, optionally named. A single
  plain list is also accepted.

## Value

A `PackedSpatRaster_list`.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
```
