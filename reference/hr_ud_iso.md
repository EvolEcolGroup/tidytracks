# Create isopleths from utilisation distributions

This method can be applied to a whole tibble of UDs, or to an individual
UD.

## Usage

``` r
hr_ud_iso(x, levels = c(0.5, 0.95))

# S3 method for class 'hr_ud_tbl'
hr_ud_iso(x, levels = c(0.5, 0.95))

# S3 method for class 'SpatRaster'
hr_ud_iso(x, levels = c(0.5, 0.95))
```

## Arguments

- x:

  either a tibble of class `hr_ud_tbl`, as created by
  [`hr_kde()`](https://evolecolgroup.github.io/tidytracks/reference/hr_kde.md),
  or a `SpatRaster` object from the `ud` column of a `hr_ud_tbl` tibble.

- levels:

  numeric vector of isopleth levels to create. Default is
  `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels
  should be between 0 and 1.

## Value

If `x` is a tibble, a tibble of class `hr_poly_tbl` with columns `id`,
`level`, and `geometry`. If `x` is a `hr_ud` object, a
`sfc_GEOMETRYCOLLECTION` object.
