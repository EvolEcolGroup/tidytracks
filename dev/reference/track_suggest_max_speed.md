# Suggest a maximum speed for each track from the data

This function suggests, for each track, a maximum speed that separates
the speeds of plausible steps from those of outliers, by looking for a
break in the distribution of the (log) speeds of the steps between
consecutive events. The suggestion can be used as `max_speed` in
[`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_mcconnell.md)
and
[`tt_clean_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_mcconnell.md).
It is a wrapper around
[`move2utils::mt_suggest_speed_cap()`](https://move2universe.github.io/move2utils/reference/mt_suggest_speed_cap.html),
applied to each track separately, which requires the suggested package
`move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
track_suggest_max_speed(
  x,
  method = c("auto", "entropy", "gap"),
  threshold = NULL,
  units = as_units("m/s")
)
```

## Arguments

- x:

  A `move2` object.

- method:

  The method used to find the break, one of "auto" (the default; an
  entropy-based method, falling back to a broken-stick method validated
  with a dip test), "entropy" or "gap". See
  [`move2utils::mt_suggest_speed_cap()`](https://move2universe.github.io/move2utils/reference/mt_suggest_speed_cap.html).

- threshold:

  A numeric value passed to the method used to find the break. The
  default `NULL` uses the default of `move2utils`.

- units:

  The units of the returned speeds, as a `units` object (e.g.
  `as_units("km/h")`). Defaults to m/s.

## Value

A `units` vector with the suggested maximum speed for each track (in the
same order as the tracks in the metadata, see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md)),
named by track id, with `NA` for the tracks for which no break was
found.

## Details

The suggestion is purely data-driven: check it against what is known
about the species (see also
[`move2utils::v_phys_estimate()`](https://move2universe.github.io/move2utils/reference/v_phys_estimate.html)).
No suggestion (`NA`) is given when no break is found, e.g. when a track
has no outliers, or when it has fewer than 10 steps with a positive
speed. Events without a location are ignored. `x` must be ordered by
time within each track (see
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)),
and have a geographic CRS or a projected CRS in metres (`move2utils`
takes projected coordinates to be in metres).

To inspect the distribution of speeds of a track, or to obtain a single
suggestion pooling all tracks, use
[`move2utils::mt_suggest_speed_cap()`](https://move2universe.github.io/move2utils/reference/mt_suggest_speed_cap.html)
directly.

## Examples

``` r
track_suggest_max_speed(example_tt)
#> Units: [m/s]
#>  a  b  c 
#> NA NA NA 
```
