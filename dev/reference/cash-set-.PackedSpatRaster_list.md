# Add `SpatRaster` by name to `PackedSpatRaster_list`

`$<-` stores a `SpatRaster` by name (wrapping it automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x$name <- value
```

## Arguments

- x:

  A `PackedSpatRaster_list` to modify.

- name:

  The name of the element to set.

- value:

  A `SpatRaster` or `PackedSpatRaster` to store at the specified name.
  If value is a SpatRaster, it will be automatically wrapped as a
  PackedSpatRaster before storage.

## Value

The modified `PackedSpatRaster_list` with the specified element
replaced.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl$a <- r2 # replaces the element named "a" with r2
```
