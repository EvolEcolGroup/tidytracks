# Add `SpatRaster` objects by position or name to `PackedSpatRaster_list`

`[<-` stores `SpatRaster` objects by position or name (wrapping them
automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x[i] <- value
```

## Arguments

- x:

  A `PackedSpatRaster_list` to modify.

- i:

  The indices or names of the elements to set.

- value:

  A `SpatRaster` or `PackedSpatRaster`, or a list of them, to store at
  the specified positions. The `SpatRaster` objects are automatically
  wrapped as `PackedSpatRaster` objects before storage.

## Value

The modified `PackedSpatRaster_list` with the specified elements
replaced.

## Examples

``` r
r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
pl <- PackedSpatRaster_list(a = r1, b = r2)
pl[1:2] <- list(r2, r1) # swaps the two elements
```
