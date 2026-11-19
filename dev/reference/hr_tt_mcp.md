# Quantify the home range using minimum convex polygon (MCP)

This function estimates the home range of an animal using the minimum
convex polygon (MCP) method. Events with an empty geometry (i.e. no
location) are ignored.

## Usage

``` r
hr_tt_mcp(x, levels = c(0.5, 0.95))
```

## Arguments

- x:

  A move2 object; if explicitly grouped, the home range is estimated for
  each group, combining all tracks within each group. Otherwise, the
  track id is used as grouping variable. Every group must have events,
  so groupings with empty groups (e.g. from grouping by a factor with
  unused levels with `.drop = FALSE`) give an error.

- levels:

  A vector of levels for the contour lines. The default is
  `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges.

## Value

An `sf` tibble of subclass `hr_tt_poly_tbl` of results, with one row per
group and level (with the tracks in the order of the metadata, see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md),
if `x` is not grouped, or else with the groups in the order of
[`dplyr::group_keys()`](https://dplyr.tidyverse.org/reference/group_data.html),
i.e. sorted by the grouping variables), and columns:

- the grouping variables of `x` (the track id if `x` is not grouped),
  one column per variable, with the keys of the groups (with their own
  types, e.g. a factor, or an `sfc` column of locations from
  [`group_by_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/group_by_meta.md))

- `method`: the method used to estimate the home range (`"mcp"`)

- `level`: the level of the contour line

- `area`: the area of the home range (as computed by
  [`sf::st_area()`](https://r-spatial.github.io/sf/reference/geos_measures.html))

- `geometry`: the geometry of the home range as sf polygons; the polygon
  is empty, and its area is `NA` (with a warning), if the locations
  within the level are fewer than three, or are on a line (e.g. for
  small levels or groups with few locations)

## Details

The MCP of a group at a level is the convex hull of the proportion
`level` of its locations that are closest to their centroid (the mean of
their coordinates): the locations whose squared distance from the
centroid is at most the `level` quantile of these squared distances (as
computed by
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html)) are kept.
A level of 1 gives the convex hull of all the locations (Mohr 1947).
This is the rule of
[`amt::hr_mcp()`](https://rdrr.io/pkg/amt/man/hrest.html);
[`adehabitatHR::mcp()`](https://rdrr.io/pkg/adehabitatHR/man/mcp.html)
uses the quantile of the distances rather than of their squares, which
can keep a different set of locations when the quantile falls between
two of them.

## References

Mohr, C. O. (1947). Table of equivalent populations of North American
small mammals. *American Midland Naturalist*, 37, 223-249.
[doi:10.2307/2421652](https://doi.org/10.2307/2421652)

## Examples

``` r
example_mcp <- hr_tt_mcp(example_tt)
example_mcp
#> Simple feature collection with 6 features and 4 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 3.6119 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> # A tibble: 6 × 5
#>   track_id method level         area                                    geometry
#> * <fct>    <chr>  <dbl>        [m^2]                               <POLYGON [°]>
#> 1 a        mcp     0.95 52747834477. ((1.371 -0.0627, 1.1694 3.5288, 3.6119 2.3…
#> 2 a        mcp     0.5  14105533708. ((1.371 -0.0627, 2.2065 1.8612, 3.6119 2.3…
#> 3 b        mcp     0.95 13139194429. ((-0.9581 -1.5686, -1.427 -1.9431, -2.4405…
#> 4 b        mcp     0.5   2865637069. ((-1.427 -1.9431, -2.4405 -1.7632, -0.9581…
#> 5 c        mcp     0.95  6222600829. ((-3.8075 1.2897, -3.4103 0.8278, -4.0496 …
#> 6 c        mcp     0.5   1241642121. ((-3.4103 0.8278, -4.0496 1.0655, -3.8075 …
library(ggplot2)
ggplot(example_mcp) +
  geom_sf(aes(fill = track_id), alpha = 0.7)
```
