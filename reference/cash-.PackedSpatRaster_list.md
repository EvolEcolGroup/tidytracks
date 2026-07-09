# Returns SpatRaster by name from PackedSpatRaster_list

`$` returns a SpatRaster by position or name (unwrapping it
automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x$name
```

## Arguments

- x:

  A PackedSpatRaster_list.

- name:

  The name of the element to return.

## Value

A SpatRaster object, unwrapped from the PackedSpatRaster.
