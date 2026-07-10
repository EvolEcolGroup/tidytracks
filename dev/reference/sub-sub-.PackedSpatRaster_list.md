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
