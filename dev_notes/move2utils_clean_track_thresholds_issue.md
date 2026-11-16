# Bug report for move2utils: `mt_clean_track()` ignores three thresholds with several tracks

Draft report for the `move2utils` maintainers. The development repository of
`move2utils` is on MPCDF GitLab, mirrored at
<https://github.com/move2universe/move2utils>. Checked with `move2utils`
0.4.5 (commit `3c2c4a2`). `tidytracks` works around the problem in
`event_flag_outliers()` by passing each track to `move2utils` on its own.

---

## `mt_clean_track()` ignores `entropy_threshold`, `gap_threshold` and `persistence_filter_threshold` when `x` has several tracks

### Summary

When `x` has more than one track, `mt_clean_track()` calls itself on each
track, but does not pass on `entropy_threshold`, `gap_threshold` and
`persistence_filter_threshold`. Each track is then cleaned with the default
thresholds, whatever values are given, without an error or a warning. The
same values work as expected on a single track. `state` is not affected: it
is dispatched before `x` is split by track, and `.dispatch_by_state()` passes
the three thresholds on.

### Reproduction

``` r
library(move2utils)

path <- system.file("extdata", "synthetic_tracks.csv.gz", package = "move2utils")
d <- read.csv(gzfile(path))
d$timestamp <- as.POSIXct(d$timestamp, tz = "UTC")
m <- move2::mt_as_move2(d,
  coords = c("location.long", "location.lat"),
  time_column = "timestamp",
  track_id_column = "individual.local.identifier",
  crs = 4326
)
two <- m[move2::mt_track_id(m) %in% c("CPF_A", "CPF_D"), ]
in_a <- move2::mt_track_id(two) == "CPF_A"

# number of outliers flagged in each track
n_flagged <- function(x, ...) {
  out <- mt_clean_track(x, ..., plot = FALSE, remove = FALSE, silent = TRUE)
  tapply(out$is_outlier, as.character(move2::mt_track_id(out)), sum)
}
# the same arguments, on both tracks at once and on each track separately
compare <- function(...) {
  rbind(
    together = n_flagged(two, ...),
    separately = c(n_flagged(two[in_a, ], ...), n_flagged(two[!in_a, ], ...))
  )
}

# with the defaults, both give the same flags
compare()
#>            CPF_A CPF_D
#> together      25    63
#> separately    25    63
# gap_threshold changes the flags of CPF_A on its own, but not together
compare(gap_threshold = 0.05)
#>            CPF_A CPF_D
#> together      25    63
#> separately    28    58
# likewise for persistence_filter_threshold and CPF_D
compare(persistence_filter = "class_aware", persistence_filter_threshold = 1)
#>            CPF_A CPF_D
#> together      25    58
#> separately    25    63
```

<sup>Created on 2026-10-29 with [reprex v2.1.1](https://reprex.tidyverse.org)</sup>

`entropy_threshold` is dropped in the same way, but on this data none of the
values we tried changes the flags of a track on its own.

### Cause

In `R/mt_clean_track.R`, the call on each track in the branch for several
tracks (lines 966-996) passes on all the other arguments of
`mt_clean_track()` (`state` is always `NULL` there), but not these three:

```r
      mt_clean_track(xi,
                     v_max              = vmi,
                     ...
                     pool_by            = NULL,   # outer-only; never recurse with pool_by
                     bridge_method         = bridge_method_resolved,
                     ...
                     compact            = compact)
```

### Suggested fix

Pass them on, as `.dispatch_by_state()` already does:

```r
                     entropy_threshold            = entropy_threshold,
                     gap_threshold                = gap_threshold,
                     persistence_filter_threshold = persistence_filter_threshold,
```

With this change, the reproduction above gives the same flags together and
separately in all three calls. The propagation tests
(`tests/testthat/test-propagation.R`) only use a single track, and the test of
an object with several tracks in `tests/testthat/test-mt_clean_track.R` only
checks the number of rows, so a test like `compare()` above, on an object
with two tracks, would catch this.
