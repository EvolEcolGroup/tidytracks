# Filter the tracks based on variables from the metadata

This function is based heavily on
[`move2::filter_track_data()`](https://bartk.gitlab.io/move2/reference/dplyr-track.html),
but it is updated so that it still works if the track metadata has a
geometry column. It allows you to filter tracks based on any variables
in the metadata table, including the track ID column (which you can
specify using the track ID column name, or the shorthand `.track_id`).

## Usage

``` r
filter_by_meta(.data, ..., .track_id = NULL)
```

## Arguments

- .data:

  A move2 object

- ...:

  Selection criteria based on the variables of the track metadata
  (logical conditions, as in
  [`dplyr::filter()`](https://dplyr.tidyverse.org/reference/filter.html));
  to select tracks by their ids, use `.track_id`

- .track_id:

  A vector of the ids of the tracks to select

## Value

A move2 object with only the selected tracks

## Details

Locations in the metadata (e.g. of a colony), stored as `sfc` columns
(see
[`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/dev/reference/sf_point_col.md))
or as the geometry of an `sf` table of metadata, can be used in the
conditions, e.g. with the spatial predicates of `sf` (such as
[`sf::st_intersects()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)
or
[`sf::st_is_within_distance()`](https://r-spatial.github.io/sf/reference/geos_binary_pred.html)).
The events keep their own geometry.

## Examples

``` r
subset_tt <- example_tt %>% filter_by_meta(sex == "female")
show_meta(subset_tt)
#>   track_id    sex nest_lon nest_lat
#> 1        c female    -0.78     0.43

# store the locations of the nests as an sfc column of the metadata
nests_tt <- example_tt
show_meta(nests_tt)$nest <- sf_point_col(
  x = show_meta(nests_tt)$nest_lon,
  y = show_meta(nests_tt)$nest_lat,
  crs = 4326
)
# keep the tracks with a nest within 200 km of a point
centre <- sf_point_col(x = 0, y = 0, crs = 4326)
nests_tt %>%
  filter_by_meta(sf::st_is_within_distance(
    nest, centre,
    dist = 200000, sparse = FALSE
  )[, 1]) %>%
  show_meta()
#>   track_id    sex nest_lon nest_lat               nest
#> 1        a   male     1.37     0.06  POINT (1.37 0.06)
#> 2        c female    -0.78     0.43 POINT (-0.78 0.43)
```
