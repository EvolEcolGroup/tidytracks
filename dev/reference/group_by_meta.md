# Group the events by variables from the metadata

This function groups the events of a `move2` object by one or more
variables of the track metadata (e.g. the sex of each animal), for
example to estimate a home range for each group with the `hr_tt_*()`
functions, which return the grouping variables as columns. It is the
counterpart of
[`filter_by_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/filter_by_meta.md)
for
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html),
and it replaces
[`move2::group_by_track_data()`](https://bartk.gitlab.io/move2/reference/dplyr-track.html),
so that it also works with locations in the metadata.

## Usage

``` r
group_by_meta(
  .data,
  ...,
  .add = FALSE,
  .drop = dplyr::group_by_drop_default(.data)
)
```

## Arguments

- .data:

  A move2 object

- ...:

  Variables of the track metadata to group by, or new variables computed
  from them (as in
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))

- .add:

  When `FALSE` (the default), the new groups replace any existing
  groups; when `TRUE`, they are added to them (as in
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))

- .drop:

  Whether to drop the groups formed by levels of factors that do not
  appear in the data (as in
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))

## Value

A grouped move2 object, with the grouping variables moved from the
metadata to the events

## Details

To group the events, the grouping variables are moved from the metadata
to the events (as
[`as_event_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_event_column.md)
does), so that the only column in both tables is the track id. They stay
in the events after
[`dplyr::ungroup()`](https://dplyr.tidyverse.org/reference/group_by.html),
and can be moved back with
[`as_meta_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_meta_column.md);
to group again by variables that are already in the events, use
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html).
A column of the events with the name of a grouping variable is kept if
it has the same values as in the metadata (e.g. moved there by
[`as_event_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_event_column.md)
with `.keep = TRUE`); otherwise, an error is raised.

The grouping variables are evaluated on the metadata, so they can also
be new variables computed from its columns (e.g.
`north = nest_lat > 0`), as in
[`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html);
the columns used to compute them stay in the metadata.

Locations in the metadata (e.g. of a colony), stored as `sfc` columns
(see
[`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/dev/reference/sf_point_col.md)),
can be grouping variables, and are moved to the events as `sfc` columns;
the events keep their own geometry. An `sf` table of metadata is turned
into a plain table first, with its geometry kept as an `sfc` column,
which is renamed if it has the name of the geometry column of the events
(see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md)).

## See also

[`filter_by_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/filter_by_meta.md)
to filter the tracks by variables of the metadata, and
[`as_event_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_event_column.md)
and
[`as_meta_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_meta_column.md)
to move variables between the metadata and the events.

## Examples

``` r
# group the events by the sex of each animal
sex_tt <- example_tt %>% group_by_meta(sex)
dplyr::group_keys(sex_tt)
#> # A tibble: 2 × 1
#>   sex   
#>   <chr> 
#> 1 female
#> 2 male  
# sex has been moved from the metadata to the events
show_meta(sex_tt)
#>   track_id nest_lon nest_lat
#> 1        a     1.37     0.06
#> 2        b    -2.44    -1.76
#> 3        c    -0.78     0.43

# group by a new variable computed from the metadata
example_tt %>%
  group_by_meta(nest_north = nest_lat > 0) %>%
  dplyr::group_keys()
#> # A tibble: 2 × 1
#>   nest_north
#>   <lgl>     
#> 1 FALSE     
#> 2 TRUE      

# group by the locations of the nests, stored as an sfc column of the
# metadata
nests_tt <- example_tt
show_meta(nests_tt)$nest <- sf_point_col(
  x = show_meta(nests_tt)$nest_lon,
  y = show_meta(nests_tt)$nest_lat,
  crs = 4326
)
nests_tt %>%
  group_by_meta(nest) %>%
  dplyr::group_keys()
#> # A tibble: 3 × 1
#>            nest
#>     <POINT [°]>
#> 1   (1.37 0.06)
#> 2 (-2.44 -1.76)
#> 3  (-0.78 0.43)
```
