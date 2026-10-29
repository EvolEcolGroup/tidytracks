# Flag outliers using the methods of move2utils

This function detects outlying locations with one of the methods of the
package `move2utils`, which requires the suggested package `move2utils`
(install it with `remotes::install_github("move2universe/move2utils")`).
Most methods choose their thresholds from the data, so, unlike
[`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_mcconnell.md),
they do not require a maximum speed.

## Usage

``` r
event_flag_outliers(
  x,
  method = c("clean_track", "speed_cap", "detour", "bridge", "probability"),
  ...
)
```

## Arguments

- x:

  A `move2` object.

- method:

  The method used to detect outliers, one of "clean_track" (the
  default), "speed_cap", "detour", "bridge" or "probability" (see
  Details).

- ...:

  Further arguments passed to the `move2utils` function of the chosen
  method.

## Value

A logical vector of the same length as the number of events in `x`,
indicating which events are valid (`TRUE`) and which are outliers
(`FALSE`).

## Details

The available methods are:

- "clean_track" (the default):
  [`move2utils::mt_clean_track()`](https://move2universe.github.io/move2utils/reference/mt_clean_track.html),
  which combines the methods below and iterates until no more outliers
  are found; it is the recommended starting point.

- "speed_cap":
  [`move2utils::mt_flag_speed_cap()`](https://move2universe.github.io/move2utils/reference/mt_flag_speed_cap.html),
  which flags events on either side of an implausibly fast step, with a
  cap chosen from the data or given as `v_max` (with
  `threshold_type = "hard"`).

- "detour":
  [`move2utils::mt_flag_outliers_detour()`](https://move2universe.github.io/move2utils/reference/mt_flag_outliers_detour.html),
  which flags events for which the path to and from the neighbouring
  events is much longer than the direct distance between them (e.g.
  out-and-back spikes).

- "bridge":
  [`move2utils::mt_flag_outliers_bridge()`](https://move2universe.github.io/move2utils/reference/mt_flag_outliers_bridge.html),
  which flags events that are far from where a Brownian bridge between
  the neighbouring events would put them.

- "probability":
  [`move2utils::mt_flag_outliers()`](https://move2universe.github.io/move2utils/reference/mt_flag_outliers.html),
  which flags events with an improbable combination of speed, turning
  angle and their changes.

Further arguments are passed to the `move2utils` function through `...`
(see its documentation for the options). Physical quantities must be
given as `units` objects (e.g. `v_max = as_units(50, "km/h")`), and are
converted to the units expected by `move2utils`: speeds (`v_max`,
`physiological_ceiling`), distances (`location_error`, `jitter`,
`residual_floor`, `step_floor`, `min_leg`) and masses (`mass`).
`location_error` (for the "clean_track" and "bridge" methods) can be a
single value, one value per event, the name of a column of `x` with the
errors (as a `units` object), or `"auto"`, with which `move2utils` uses
the column `eobs_horizontal_accuracy_estimate` (which must then be a
`units` object) or, failing that, the Argos location classes. `state`
(for the "clean_track" method) can be the name of a column of `x`, or
one value per event. Each track is checked on its own, with all the
arguments (unless `pool_by` pools thresholds across tracks). The
`move2utils` functions are run without plots and messages; to inspect
their diagnostics, call them directly on `x`.

`x` must be ordered by time within each track (see
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)).
Some methods also require events with duplicated times to be removed
first (e.g. with
[`move2::mt_filter_unique()`](https://bartk.gitlab.io/move2/reference/mt_filter_unique.html)).
Events without a location are ignored, and returned as valid. Tracks
with too few events with a location for the method (10 for
"clean_track", 5 for "probability", and 2 for the other methods) are not
checked, with a warning, and their events are returned as valid.

## See also

[`tt_clean_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_outliers.md)
to remove the outliers, or replace their location.

## Examples

``` r
event_flag_outliers(example_tt, method = "detour")
#>  [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE
# use a maximum speed rather than one estimated from the data (steps in
# this toy dataset are hundreds of km long)
event_flag_outliers(
  example_tt,
  method = "speed_cap",
  v_max = as_units(1000, "km/h"),
  threshold_type = "hard"
)
#>  [1] FALSE FALSE  TRUE FALSE FALSE  TRUE  TRUE FALSE FALSE  TRUE FALSE FALSE
#> [13]  TRUE FALSE FALSE
```
