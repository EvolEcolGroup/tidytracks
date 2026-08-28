# Wrap utilisation distributions for storage

Converts the `ud` column of an `hr_ud_tbl` from a plain list of
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects to a compact wrapped `PackedSpatRaster_list`. Use
[`hr_ud_unwrap()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_unwrap.md)
to restore the standard in-memory representation.

## Usage

``` r
hr_ud_wrap(x)
```

## Arguments

- x:

  An `hr_ud_tbl` with a `ud` list-column.

## Value

A copy of `x` with a wrapped `ud` column.

## Examples

``` r
example_kde <- hr_kde(example_tt)
wrapped_kde <- hr_ud_wrap(example_kde)
```
