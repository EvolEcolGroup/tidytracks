# Create isopleths from utilisation distributions

This method can be applied to a whole tibble of UDs, or to an individual
UD.

## Usage

``` r
hr_ud_iso(x, levels = c(0.5, 0.95))

# S3 method for class 'tbl_df'
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

## See also

Other home_range:
[`hr_ud_sum()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_sum.md)

## Examples

``` r
example_kde <- hr_kde(example_tt)
example_iso <- hr_ud_iso(example_kde)
example_iso
#> Simple feature collection with 6 features and 10 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -7.624955 ymin: -4.28871 xmax: 7.82745 ymax: 5.792261
#> Geodetic CRS:  WGS 84
#> # A tibble: 6 × 11
#>   track_id method     h  xmin  ymin  xmax  ymax   res level          area
#>   <chr>    <chr>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>         [m^2]
#> 1 a        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5  165392600801.
#> 2 a        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 656939585304.
#> 3 b        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5   95349646303.
#> 4 b        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 418935814644.
#> 5 c        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5  112048649312.
#> 6 c        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 508659872486.
#> # ℹ 1 more variable: geometry <MULTIPOLYGON [°]>

# now plot the isopleths
library(ggplot2)
ggplot(example_iso) +
  geom_sf(aes(fill = track_id), alpha = 0.7)
```
