# Create isopleths from utilisation distributions

This method can be applied to a whole tibble of UDs, or to an individual
UD.

## Usage

``` r
hr_tt_ud_iso(x, levels = c(0.5, 0.95), ci_level = 0.95)

# S3 method for class 'tbl_df'
hr_tt_ud_iso(x, levels = c(0.5, 0.95), ci_level = 0.95)

# S3 method for class 'SpatRaster'
hr_tt_ud_iso(x, levels = c(0.5, 0.95), ci_level = 0.95)
```

## Arguments

- x:

  either a tibble of class `hr_tt_ud_tbl`, as created by
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md),
  or a `SpatRaster` object from the `ud` column of a `hr_tt_ud_tbl`
  tibble.

- levels:

  numeric vector of isopleth levels to create. Default is
  `c(0.50, 0.95)`, which will create 50% and 95% isopleths. Levels
  should be between 0 and 1.

- ci_level:

  The confidence level of the confidence intervals of the areas of the
  isopleths, which are computed for the UDs estimated with `ctmm` (i.e.
  a table with a `ud_ctmm` column, as returned by
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
  and
  [`hr_tt_akde_pop()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde_pop.md));
  it is ignored for other UDs. Default is 0.95.

## Value

If `x` is a `SpatRaster`, an `sf` object with one row per level and
columns `level`, `area` (the area of the isopleth) and `geometry` (a
`MULTIPOLYGON` for the isopleth). If `x` is a tibble, an `sf` tibble of
class `hr_tt_poly_tbl` with the columns of `x` (except `ud` and
`ud_ctmm`) and, for each UD, one row per level with these three columns.
For the UDs estimated with `ctmm`, the columns `area_low` and
`area_high` (the confidence interval of the home range area at each
level, as estimated by `ctmm`) are added after `area` (in a table that
combines them with other UDs, e.g. from
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md),
the other UDs get `NA`).

## See also

Other home_range:
[`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)

## Examples

``` r
example_kde <- hr_tt_kde(example_tt)
example_iso <- hr_tt_ud_iso(example_kde)
example_iso
#> Simple feature collection with 6 features and 10 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -7.665867 ymin: -4.377112 xmax: 7.900379 ymax: 5.851994
#> Geodetic CRS:  WGS 84
#> # A tibble: 6 × 11
#>   track_id method     h  xmin  ymin  xmax  ymax   res level          area
#> * <chr>    <chr>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>         [m^2]
#> 1 a        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5  169367467153.
#> 2 a        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 686843555092.
#> 3 b        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5   99573159553.
#> 4 b        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 436476848051.
#> 5 c        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.5  118862309232.
#> 6 c        kde     1.06 -16.5 -7.42  16.6  9.54 0.737  0.95 530109135082.
#> # ℹ 1 more variable: geometry <MULTIPOLYGON [°]>

# now plot the isopleths
library(ggplot2)
ggplot(example_iso) +
  geom_sf(aes(fill = track_id), alpha = 0.7)
```
