# Print a summary of the `PackedSpatRaster_list`

Print a summary of the `PackedSpatRaster_list`, showing dimensions and
CRS of each element. This provides a quick overview of the contents of
the list without the overhead of unwrapping all rasters.

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
print(x, ...)
```

## Arguments

- x:

  A `PackedSpatRaster_list` to print.

- ...:

  Not used.

## Value

The original `PackedSpatRaster_list`, invisibly.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl # prints a summary of the PackedSpatRaster_list
#> <PackedSpatRaster_list[2]>
#>   $a <SpatRaster [4x4x1] WGS 84>
#>   $b <SpatRaster [4x4x1] WGS 84 (CRS84)>
```
