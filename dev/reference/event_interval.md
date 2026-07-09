# Measure the time interval between pairs of consecutive events within each track

This function measures the interval (i.e. time interval) between
adjacent pairs of consecutive events within each track. It returns a
vector of intervals of the same length as the number of events in `x`,
with the value for the last event of each track padded with an NA.

## Usage

``` r
event_interval(x, units)
```

## Arguments

- x:

  A move2 object

- units:

  Optional, the time units (as `character`, `symbolic_units` or `units`)
  used to represent the intervals. It defaults to the units of the input
  data.

## Value

a vector of time intervals of the same length as the number of events in
`x`, with the last value set to NA for each track.

## Details

This is a wrapper around
[`move2::mt_time_lags()`](https://bartk.gitlab.io/move2/reference/mt_time.html).
Note that the timestamps of events have to be ordered for this function
to work correctly (you can use
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)
to order your tibble of tracks.

## Examples

``` r
event_interval(example_tt)
#> Units: [min]
#>  [1] 20 20 20 20 NA 20 20 20 20 NA 20 20 20 20 NA
event_interval(example_tt, units = "hours")
#> Units: [h]
#>  [1] 0.3333333 0.3333333 0.3333333 0.3333333        NA 0.3333333 0.3333333
#>  [8] 0.3333333 0.3333333        NA 0.3333333 0.3333333 0.3333333 0.3333333
#> [15]        NA
```
