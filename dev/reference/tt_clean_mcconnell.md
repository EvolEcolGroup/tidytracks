# Clean a `move2` object using McConnell's algorithm

This function cleans a `move2` object using McConnell's algorithm. It
removes outliers based on the distance between consecutive points and
the time interval between them (more explanation; give reference TODO).
This function returns a clean `move2` object; to generate a column that
flags events to remove but does not remove them, use
[`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_mcconnell.md).

## Usage

``` r
tt_clean_mcconnell(
  x,
  max_speed = NULL,
  flag_action = c("remove", "interpolate", "null"),
  check_first_last = FALSE
)
```

## Arguments

- x:

  A move2 object

- max_speed:

  speed, provided as a `units` object (e.g. as_units(50, 'm/s').

- flag_action:

  One of "remove", "null", or "interpolate", to either remove the points
  flagged by the algorithm, keep the time stamp but set location to
  NULL, or replace the location with a linearly interpolated location
  from the events that were not filtered out.

- check_first_last:

  Logical. If `TRUE`, also evaluate the first and last currently valid
  point of each track using the endpoint RMS described above. If either
  endpoint is removed, the McConnell filter is rerun on the reduced
  track until the result is stable.

## Value

A clean `move2` object with events removed
