# Compute the total distance of each track

Compute the total distance of each track

## Usage

``` r
track_tot_distance(x, units = as_units("m"))
```

## Arguments

- x:

  A `move2` object

- units:

  The units to use for the distance. Default is "m".

## Value

A vector of total distances for each track, named by track id and in the
same order as the tracks in the metadata (see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md))

## Examples

``` r
track_tot_distance(example_tt)
#> Units: [m]
#>         a         b         c 
#> 1170506.6  870617.4  812657.4 
track_tot_distance(example_tt, units = "km")
#> Units: [km]
#>         a         b         c 
#> 1170.5066  870.6174  812.6574 
```
