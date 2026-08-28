# Drop units from a tibble of tracks

Many functions in `tidytracks` produced values with units (implemented
via the package `units`). Units are very useful in ensuring that
operations are performed in the correct units, but they are not always
compatible with other packages, such as `ggplot2`. This function drops
the units from the columns of a `move2` or `sf` object.

## Usage

``` r
tt_drop_units(x)
```

## Arguments

- x:

  A `move2` or `sf` object

## Value

A `move2` or `sf` object with units dropped

## Details

Note that `geom_*` functions in `tidytracks` automatically drop units,
so there is no need to use this function before plotting if you use the
custom geometries in this package.

## Examples

``` r
# Add speed column (with units) to example_tt
example_tt$speed <- event_speed(example_tt)
class(example_tt$speed)
#> [1] "units"
# Drop the units from any columns with units
result <- tt_drop_units(example_tt)
class(result$speed)
#> [1] "numeric"
```
