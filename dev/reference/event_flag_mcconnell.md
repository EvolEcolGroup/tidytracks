# Clean data based on speed

This function uses the algorithm by McConnell et al. (2012) to clean
data based on speed. This is a port of the `speedfilter` function from
the `trip` package, with an optional endpoint check.

## Usage

``` r
event_flag_mcconnell(x, max_speed = NULL, check_first_last = FALSE)
```

## Arguments

- x:

  A move2 object.

- max_speed:

  Speed, provided as a `units` object, e.g. `as_units(50, "m/s")`.

- check_first_last:

  Logical. If `TRUE`, also evaluate the first and last currently valid
  point of each track using the endpoint RMS described above. If either
  endpoint is removed, the McConnell filter is rerun on the reduced
  track until the result is stable. It defaults to `FALSE` to maintain
  the original behaviour of the McConnell algorithm.

## Value

A logical vector of the same length as the number of events in `x`,
indicating which points are valid.

## Details

When `check_first_last = TRUE`, the function also evaluates the first
and last currently valid point of each track using an endpoint Root Mean
Square (RMS):

- first point: RMS of speed(1,2) and speed(1,3)

- last point: RMS of speed(n-1,n) and speed(n-2,n)

If an endpoint is removed, the McConnell filter is rerun on the reduced
track, and the endpoint check is repeated until the result is stable.

## Examples

``` r
event_flag_mcconnell(example_tt, max_speed = as_units(50, "m/s"))
#>  [1]  TRUE  TRUE FALSE  TRUE  TRUE  TRUE  TRUE FALSE  TRUE  TRUE  TRUE  TRUE
#> [13] FALSE  TRUE  TRUE
```
