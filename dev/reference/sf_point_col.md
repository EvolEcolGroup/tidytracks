# Create a simple feature POINT geometry column

This function creates a simple feature POINT geometry column from x and
y columns in a data frame. The resulting object is a `sf` geometry set
that can be used as an additional spatial column in an sf data frame, in
addition to the primary geometry column.

## Usage

``` r
sf_point_col(x, y, crs = sf::NA_crs_)
```

## Arguments

- x:

  A vector of x coordinates (e.g., longitude or easting)

- y:

  A vector of y coordinates (e.g., latitude or northing)

- crs:

  An optional coordinate reference system (CRS) to assign to the
  geometry. This can be an EPSG code (numeric) or a proj4 string
  (character). If not set (default), no CRS is assigned.

## Value

A `sf` geometry set of POINT geometries

## Examples

``` r
sf_point_col(
  x = show_meta(example_tt)$nest_lon,
  y = show_meta(example_tt)$nest_lat,
  crs = 4326
)
#> Geometry set for 3 features 
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -2.44 ymin: -1.76 xmax: 1.37 ymax: 0.43
#> Geodetic CRS:  WGS 84
#> POINT (1.37 0.06)
#> POINT (-2.44 -1.76)
#> POINT (-0.78 0.43)

# assign to a column in the meta with mutate
library(dplyr)
#> 
#> Attaching package: ‘dplyr’
#> The following objects are masked from ‘package:stats’:
#> 
#>     filter, lag
#> The following objects are masked from ‘package:base’:
#> 
#>     intersect, setdiff, setequal, union
show_meta(example_tt) %>%
  mutate(nest_coord = sf_point_col(
    x = show_meta(example_tt)$nest_lon,
    y = show_meta(example_tt)$nest_lat,
    crs = 4326
  ))
#>   track_id    sex nest_lon nest_lat          nest_coord
#> 1        a   male     1.37     0.06   POINT (1.37 0.06)
#> 2        b   male    -2.44    -1.76 POINT (-2.44 -1.76)
#> 3        c female    -0.78     0.43  POINT (-0.78 0.43)
```
