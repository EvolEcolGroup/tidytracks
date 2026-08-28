# Subset a `PackedSpatRaster_list` by position or name

`[` subsets and returns a new `PackedSpatRaster_list` (still packed)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x[i, ...]
```

## Arguments

- x:

  A `PackedSpatRaster_list`.

- i:

  The indices or names of the elements to subset.

- ...:

  Additional arguments passed to
  [`NextMethod()`](https://rdrr.io/r/base/UseMethod.html), for
  compatibility with generic.

## Value

A new `PackedSpatRaster_list` containing the specified subset of
elements.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl["a"] # returns a new PackedSpatRaster_list with only r1
#> <PackedSpatRaster_list[1]>
#>   $a <SpatRaster [4x4x1] WGS 84>
```
