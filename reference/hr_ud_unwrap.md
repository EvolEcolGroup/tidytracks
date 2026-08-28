# Unwrap utilisation distributions after loading

Converts the `ud` column of an `hr_ud_tbl` from a wrapped
`PackedSpatRaster_list` to the standard plain list of
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects. This is needed after loading a file created with
[`hr_ud_saveRDS()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_saveRDS.md).
Functions that operate on `hr_ud_tbl` objects unwrap their input
automatically, but explicitly unwrapping avoids repeating that work
across multiple operations.

## Usage

``` r
hr_ud_unwrap(x)
```

## Arguments

- x:

  An `hr_ud_tbl` with a `ud` list-column.

## Value

A copy of `x` with an unwrapped `ud` column.

## Examples

``` r
example_kde <- hr_kde(example_tt)
unwrapped_kde <- hr_ud_unwrap(hr_ud_wrap(example_kde))
```
