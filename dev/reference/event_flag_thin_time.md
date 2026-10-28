# Flag events to keep when thinning tracks to a time interval

This function selects, within each track, the largest subset of events
such that consecutive selected events are separated by `interval` (plus
or minus `tolerance`). Unlike
[`tt_regular_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_regular_time.md),
which interpolates new locations on a regular time grid, this keeps a
subset of the original events. It is a wrapper around
[`move2utils::mt_thin_time()`](https://move2universe.github.io/move2utils/reference/mt_thin_time.html),
which requires the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
event_flag_thin_time(
  x,
  interval,
  tolerance = NULL,
  criterion = c("closest", "first")
)
```

## Arguments

- x:

  A `move2` object.

- interval:

  The target time interval between consecutive kept events, as a `units`
  object (e.g. `as_units(1, "h")`).

- tolerance:

  The accepted deviation from `interval`, as a `units` object with time
  units. Defaults to `interval / 10`.

- criterion:

  How to choose among subsets with the same number of events: "closest"
  (the default) keeps the subset whose intervals deviate least from
  `interval` in total, "first" keeps the subset that starts earliest.

## Value

A logical vector with one value per event of `x`, `TRUE` for the events
to keep.

## Details

Tracks are split at any gap longer than `interval + tolerance`: thinning
never bridges such a gap. When several subsets of the same size exist,
`criterion` decides which one is kept. Events without a location are
never kept. `x` does not need to be ordered by time. To remove the
events that are not kept, use
[`tt_thin_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_thin_time.md).

## Examples

``` r
# keep events 40 minutes apart (events in example_tt are 20 minutes apart)
event_flag_thin_time(example_tt, interval = as_units(40, "min"))
#>  [1]  TRUE FALSE  TRUE FALSE  TRUE  TRUE FALSE  TRUE FALSE  TRUE  TRUE FALSE
#> [13]  TRUE FALSE  TRUE
```
