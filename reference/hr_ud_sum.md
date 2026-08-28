# Compute the normalised sum of multiple UDs

This functions takes a tibble of UDs and computes the normalised sum of
the UDs. The normalised sum is computed by summing the UDs and then
dividing by the number of UDs so that the resulting UD integrates (sums)
to 1 (since each input UD sums to 1). This is equivalent to dividing by
the sum of values in the combined UDs).

## Usage

``` r
hr_ud_sum(x)

# S3 method for class 'list'
hr_ud_sum(x)

# S3 method for class 'tbl_df'
hr_ud_sum(x)

# S3 method for class 'grouped_df'
hr_ud_sum(x)
```

## Arguments

- x:

  A tibble of UDs (potentially grouped), where each row is a UD in the
  column named "ud", or a list of SpatRaster objects representing UDs.

## Value

either a tibble of UDs with the number of rows equal to the number of
groups in `x` (or just one row for an ungrouped tibble), or a single
SpatRaster if `x` is a list of SpatRaster objects.

## See also

Other home_range:
[`hr_ud_iso()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_iso.md)

## Examples

``` r
example_kde <- hr_kde(example_tt)
# sum the UDs for all tracks in the tibble
hr_ud_sum(example_kde)
#> # A tibble: 1 × 8
#>   method     h  xmin  ymin  xmax  ymax   res ud               
#>   <chr>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <list>           
#> 1 kde     1.06 -16.5 -7.42  16.6  9.54 0.737 <SpatRstr[,45,1]>
# add sex info from metadata and use it to group the UDs
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union
example_kde_grouped <- example_kde %>%
 left_join(show_meta(example_tt)) %>%
 group_by(sex)
#> Joining with `by = join_by(track_id)`
hr_ud_sum(example_kde_grouped)
#> # A tibble: 2 × 9
#> # Groups:   sex [2]
#>   sex    method     h  xmin  ymin  xmax  ymax   res ud               
#>   <chr>  <chr>  <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <list>           
#> 1 female kde     1.06 -16.5 -7.42  16.6  9.54 0.737 <SpatRstr[,45,1]>
#> 2 male   kde     1.06 -16.5 -7.42  16.6  9.54 0.737 <SpatRstr[,45,1]>
```
