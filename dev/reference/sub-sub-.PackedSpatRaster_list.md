# Returns `SpatRaster` by position or name from `PackedSpatRaster_list`

`[[` returns a `SpatRaster` by position or name (unwrapping it
automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x[[i, ...]]
```

## Arguments

- x:

  A `PackedSpatRaster_list`.

- i:

  The index or name of the element to return.

- ...:

  unused, for compatibility with generic. Additional arguments are
  ignored.

## Value

A `SpatRaster` object, unwrapped from the `PackedSpatRaster`.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl[[1]] # returns r1 as a SpatRaster
#> class       : SpatRaster
#> size        : 4, 4, 1  (nrow, ncol, nlyr)
#> resolution  : 90, 45  (x, y)
#> extent      : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> name        : lyr.1
#> min value   :     1
#> max value   :    16
```
