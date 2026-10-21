# Compute the total duration of each track

Compute the total duration of each track

## Usage

``` r
track_duration(x, units = as_units(1, "days"))
```

## Arguments

- x:

  A `move2` object

- units:

  The units to use for the duration. Default is "days".

## Value

A vector of total durations for each track, named by track id and in the
same order as the tracks in the metadata (see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/reference/show_meta.md))

## Examples

``` r
track_duration(example_tt)
#> Units: [d]
#>          a          b          c 
#> 0.05555556 0.05555556 0.05555556 
```
