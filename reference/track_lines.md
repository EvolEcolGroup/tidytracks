# Return a trajectory line for each track

Converts each track into one line. This function returns a
[`sf::sf`](https://r-spatial.github.io/sf/reference/sf.html) object with
a `LINESTRING` representing the trajectory as geometry for each track,
as well as additional columns of information from the metadata table.

## Usage

``` r
track_lines(x, ...)
```

## Arguments

- x:

  A move object

- ...:

  Arguments passed on to the
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
  function

## Value

A [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) object with
a `LINESTRING` representing the track as geometry for each track. The
metadata for each track is included as well as the products from
summarize

## Details

Note that all empty points are removed before summarizing. Arguments
passed with `...` thus only summarize for the non empty locations.

## Examples

``` r
track_lines(example_tt)
#> Simple feature collection with 3 features and 4 fields
#> Geometry type: LINESTRING
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> # A tibble: 3 × 5
#>   track_id                                      geometry sex   nest_lon nest_lat
#>   <fct>                                 <LINESTRING [°]> <chr>    <dbl>    <dbl>
#> 1 a        (1.371 -0.0627, 1.1694 3.5288, 2.2065 1.8612… male      1.37     0.06
#> 2 b        (-2.4405 -1.7632, -1.427 -1.9431, -3.3802 -0… male     -2.44    -1.76
#> 3 c        (-0.7845 0.4328, -4.0496 1.0655, -3.8075 1.2… fema…    -0.78     0.43
```
