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

  The identifiers of one or more tracks to select or selection criteria
  based on track metadata

- .track_id:

  A vector of the ids of the tracks to select

## Value

A move2 object with only the selected tracks

## Examples

``` r
subset_tt <- example_tt %>% filter_by_meta(sex == "female")
show_meta(subset_tt)
#>   track_id    sex nest_lon nest_lat
#> 1        c female    -0.78     0.43
```
