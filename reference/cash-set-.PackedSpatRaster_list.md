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
