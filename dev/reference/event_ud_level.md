# Find the isopleth level of each event in a utilisation distribution

This function returns, for each event, the level of the smallest
isopleth of a utilisation distribution (UD) that contains its location,
i.e. the proportion of the UD in the cells with a density at least as
high as the cell of the event. Values near 0 indicate events in the core
of the UD; values near 1 indicate events in its periphery (e.g. an event
with a value of 0.6 lies outside the 50% home range but inside the 95%
one). It is a wrapper around
[`move2utils::ud_outer_probability()`](https://move2universe.github.io/move2utils/reference/ud_outer_probability.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
event_ud_level(x, ud)
```

## Arguments

- x:

  A `move2` object.

- ud:

  A UD, either as a
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  (with a layer named `ud`, or a single layer), or as a tibble of class
  `hr_tt_ud_tbl`.

## Value

A numeric vector with one value per event of `x`, between 0 and 1.

## Details

`ud` can be a single UD, used for all events, or a tibble of UDs (of
class `hr_tt_ud_tbl`, as returned by e.g.
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
or
[`hr_tt_dbbmm()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md)).
With a tibble, the level of each event is computed in the UD of its own
row, matching the first column of the tibble (e.g. the track id) to the
column of `x` with the same name; a tibble with a single row is used for
all events.

Events are reprojected to the coordinate reference system of the UD if
needed. Events without a location, outside the grid of the UD, or
without a matching UD get `NA`.

## Examples

``` r
ud <- hr_tt_kde(example_tt)
# the level of each event in the UD of its own track
event_ud_level(example_tt, ud)
#>  [1] 0.37912908 0.20519589 0.02592777 0.24422211 0.46157643 0.12108702
#>  [7] 0.04158419 0.54295652 0.52136846 0.22928935 0.52545507 0.07887490
#> [13] 0.04175892 0.04175892 0.61434549
# the level of each event in the UD of track "a"
event_ud_level(example_tt, ud$ud[["a"]])
#>  [1] 0.37912908 0.20519589 0.02592777 0.24422211 0.46157643 0.99989931
#>  [7] 0.99664072 1.00000000 0.78633036 0.98434300 0.93014376 1.00000000
#> [13] 1.00000000 1.00000000 1.00000000
```
