# Unpack all rasters into a plain list of live `SpatRasters`

Unpack all rasters into a plain list of live `SpatRasters`

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
as.list(x, ...)
```

## Arguments

- x:

  `PackedSpatRaster_list` to convert

- ...:

  Not used.

## Value

A plain list of `SpatRaster` objects, unwrapped from the
`PackedSpatRaster_list`.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
lst <- as.list(pl) # returns a plain list of SpatRasters
lst
#> $a
#> class       : SpatRaster
#> size        : 4, 4, 1  (nrow, ncol, nlyr)
#> resolution  : 90, 45  (x, y)
#> extent      : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
#> source(s)   : memory
#> name        : lyr.1
#> min value   :     1
#> max value   :    16
#> 
#> $b
#> class       : SpatRaster
#> size        : 4, 4, 1  (nrow, ncol, nlyr)
#> resolution  : 90, 45  (x, y)
#> extent      : -180, 180, -90, 90  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (CRS84) (OGC:CRS84)
#> source(s)   : memory
#> name        :    lyr.1
#> min value   :  -1.5124
#> max value   : 1.888505
#> 
```
