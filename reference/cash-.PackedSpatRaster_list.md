# Returns `SpatRaster` by name from `PackedSpatRaster_list`

`$` returns a `SpatRaster` by position or name (unwrapping it
automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x$name
```

## Arguments

- x:

  A `PackedSpatRaster_list`.

- name:

  The name of the element to return.

## Value

A `SpatRaster` object, unwrapped from the `PackedSpatRaster_list`.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl$a # returns r1 as a SpatRaster
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
