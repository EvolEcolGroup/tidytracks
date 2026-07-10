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
