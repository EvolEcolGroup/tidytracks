# Code review of the FPT functions (branch `fpt`), November 2026

## Summary

- **Branch reviewed:** `fpt`, commit `fea842f` ("First attempt to implement
  First Passage Time (FPT) functionality"), by Lizzie Pearmain, i.e. the
  changes from its parent `f841a16` (the `inbound` work, merged into `dev` as
  #91): the new `event_fpt()`, `track_fpt_profile()` (with an `autoplot()`
  method), `track_suggest_ars_scale()` and `src/fpt.cpp`.
- **Fixes:** 7 commits on the local branch `codereview_fpt`, from `fea842f`
  (5 bugs, 1 documentation fix, 1 R CMD check NOTE), plus this report.
- **Optional branch:** `codereview_fpt_speedup`, from `9a5bede` (on
  `codereview_fpt`), 2 commits: an exact speed-up of the search in
  `fpt_cpp()`, 9× faster on a 72k-fix track and about linear rather than
  quadratic in the length of a track, with identical results and no slowdown
  elsewhere.
- **Findings not fixed:** 9, of which 4 need a decision.
- **Headline:** the FPTs are right. They equal `adehabitatLT::fpt()` exactly
  (same values, same missing values) on 11 real datasets, 1,655,175
  event × radius values. The problems were in the scale suggestion, in the
  speed on long tracks or many tracks, and in the defaults (not fixed:
  decision needed).
- Nothing is pushed.

## Verification

All on the laptop (laptopX1), 16 November 2026.

| Check | Where | Result |
|---|---|---|
| R CMD check (`--no-manual`, `NOT_CRAN=true`, all Suggests installed): tests, examples, vignette, dependencies of the tests | `codereview_fpt` at `308a6c4`, built from a clean copy | Status: OK (examples, vignette, spelling and dependencies of the tests OK) |
| Full test suite | same | 1,655 passed, 0 failed, 0 warnings, 0 skipped |
| `lintr::lint_package()` | `codereview_fpt` at `1607f5a`, with that build first in `.libPaths()` | 0 lints |
| Full test suite, installed -O2 build | `codereview_fpt_speedup` at `968c604` | 1,656 passed, 0 failed, 0 warnings, 0 skipped |
| FPT test files (3) | each fix commit, by a separate verifying agent | all pass |
| New tests fail before the fix | `23a8e95`, `24e9118`, by the verifying agent | both fail before, pass after |
| `fpt_cpp()` against the original | `968c604` vs `fea842f`, 12 real datasets, 40 radii each | identical (5.1 million values) |
| Profiles against the original | `9a5bede` vs `fea842f`, 17 profiles of real data | identical |

`lint_package()` also reports false `object_usage_linter` warnings for the
new internal functions when the tidytracks installed in the default library
is from another branch (it does the same for `ctmm_tt_fit.R` and
`hr_tt_akde.R`); with this branch installed, as on CI, it finds none.

Exceptions to "each test fails before the fix":

- `75702dc` (Suggests): no testthat test is possible. R CMD check's own
  check of the dependencies of the tests
  (`tools:::.check_packages_used_in_tests()`) lists `adehabitatLT` before the
  fix and nothing after.
- `3a96ca0` (interrupts): an interrupt cannot be tested with testthat.
  Checked by hand: SIGINT sent 4 s into a 72k-location run; before the fix
  the run went on to the end (19.7 s); after, it stopped at 9.3 s, before the
  end (wall times on a loaded laptop, unoptimised build for the fix). The
  verifying agent also saw a 40k-location run stop 1.6 s in.
- `9a5bede` (speed): no new test; outputs identical (above) and benchmarked
  (below).
- `1607f5a` (documentation) and `308a6c4` (WORDLIST): no test; the spelling
  test of R CMD check passes after `308a6c4`.
- `1045a66` and `968c604` (speed, optional branch): no new test, but the
  comparison with `adehabitatLT` now uses 300 locations and a circle that is
  never left, so that it covers the block skipping; it fails if the search
  skips blocks only partly inside the circle (checked by mutating the code).

### Benchmarks

Laptop, so indicative only. Each version installed from a clean copy
(-O2), each run in its own R process pinned to one core (`taskset -c 2`),
three runs per version in balanced order (A B B A A B), load about 1. Median
(min-max) of the timed call, after a warm-up call; instructions are for the
whole process (start-up, data and both calls). Outputs identical in every
run.

| Workload | Before | After | Instructions (G) |
|---|---|---|---|
| `9a5bede`: `track_fpt_profile()`, 2,280 daily fisher tracks (285k events), 5 radii | 3.30 s (2.83-3.31) | 0.65 s (0.65-0.68) | 68.4 → 32.6 |
| `9a5bede`: shag trips grouped by bird (7 groups), default radii | 0.058 s (0.056-0.058) | 0.060 s (0.059-0.069) | 10.65 → 10.65 |
| `968c604`: 72,569-fix albatross, `track_fpt_profile()` default radii | 5.53 s (5.36-5.57) | 0.61 s (0.60-0.61) | 182.8 → 20.0 |
| `968c604`: same track, 10 small radii | 0.086 s (0.086-0.086) | 0.081 s (0.081-0.085) | 11.13 → 10.80 |
| `968c604`: 11 datasets, 10 small radii (0.5-5 median steps) | 0.043 s (0.042-0.043) | 0.043 s (0.042-0.045) | 10.22 → 10.22 |
| `968c604`: 11 datasets, 40 wide radii | 0.255 s (0.252-0.261) | 0.129 s (0.129-0.130) | 15.97 → 11.39 |
| `968c604`: 11 datasets, default radii | 0.281 s (0.281-0.286) | 0.164 s (0.164-0.166) | 16.10 → 11.77 |
| `968c604`: 2,280 short tracks, 5 radii | 0.559 s (0.556-0.600) | 0.563 s (0.561-0.568) | 32.56 → 32.33 |

The first version of the speed-up (`1045a66` alone) was 10% slower on the
small radii (0.043 → 0.048 s); `968c604` removed that. With `968c604`, the
time for the 50 default-like radii grows about linearly with the length of a
track: 0.29, 0.75, 1.56 and 3.58 s for 73k, 145k, 290k and 581k fixes (the
albatross trip repeated), against about 4× per doubling before (0.21, 0.76
and 2.86 s for 9k, 18k and 36k fixes for one never-left radius, under load).

## How the review was done

- Read the diff of `fea842f` and the helpers it uses (`check_time_ordered()`,
  `hr_group_order()`, `check_no_empty_groups()`, `tt_split_trips()`).
- Real data, projected to a local azimuthal equidistant projection (or kept
  in their own UTM or Albers projection): European shags (the raw and the
  cleaned vignette data, and their trips from `tt_split_trips()`), African
  buffalo (ctmm article), wandering albatrosses (12-hourly, from the
  animation article; one 4-second GPS trip of 72,569 fixes from `data-raw/`;
  the BirdLife example), the Argos albatrosses of `adehabitatLT`, the pelican,
  coatis and jaguars of `ctmm`, the fishers of `amt` and the wild boar of the
  tests.
- Compared `event_fpt()` and `fpt_matrix()` with `adehabitatLT::fpt()`, track
  by track, for 25 radii per dataset from half the median step to half the
  extent of the data.
- Checked units (radii in km on a CRS in US survey feet, against the same
  projection in metres: equal to 3e-12), duplicated times, events without a
  location, the `trip_na` dummy trips, groups of one and two variables,
  profiles reordered by the user, and numeric, `Date` and `units` time
  columns.
- Computed the profiles with the default radii of every dataset, plotted
  them, and compared the scales suggested by each method with the peaks
  visible in the plots.
- Timed the run time against the length of a track and the number of tracks,
  profiled `track_fpt_profile()` with `Rprof`, and benchmarked the fixes
  (above).
- A separate agent verified each fix commit: its diff, and that its test
  fails before and passes after.

## Changes in behaviour to check before merging

- `track_suggest_ars_scale()` returns `NA` for flat profiles whose variances
  differ only by rounding (`23a8e95`), where it returned a radius before.
  Differences smaller than `sqrt(.Machine$double.eps)` times the largest
  variance (or 1, as the variance of the log FPT has no units) are ties. No
  suggestion changed for the default radii of the 11 real datasets (486
  combinations of track, method and width).
- `track_suggest_ars_scale()` sorts the rows of each track of a profile by
  radius (`24e9118`): only profiles reordered by the user give different
  results.
- No NEWS entries: the fixes are to functions that are new in this
  development version, whose NEWS item still describes them correctly.

## Fixes by area

### Scale suggestion

- [ ] `23a8e95` · `fpt_peak()` (`track_suggest_ars_scale()`) — rounding noise
  in flat profiles counted as peaks: for radii smaller than all the steps of a
  track (the FPT is then proportional to the radius) it suggested scales from
  differences of about 1e-15, e.g. 20, 40 and 50 m for `example_tt`, and a
  scale for most fishers, jaguars and coatis *[wrong suggestions]*
- [ ] `24e9118` · `track_suggest_ars_scale()` — took the rows of a profile in
  the order given: a profile reordered with `dplyr::arrange(desc(radius))`
  (which keeps its class) gave the peak at the largest radius, e.g. 7-9.5 km
  instead of 1.5-4 km for the buffalo *[wrong suggestions]*
- [ ] `1607f5a` · `track_suggest_ars_scale()` — documentation: the scales are
  in the order in which the ids first appear in the profile, which since
  `24e9118` need not be that of `track_fpt_profile()` *[documentation]*

### Package and checks

- [ ] `75702dc` · DESCRIPTION — `adehabitatLT` used in the tests but not in
  Suggests, so R CMD check reports the undeclared `::` import in the tests.
  Correction to the commit message: CI did run the comparison, as
  `adehabitatHR` (in Suggests) depends on `adehabitatLT` *[check warning]*
- [ ] `308a6c4` · `inst/WORDLIST` — the spelling test flagged ARS, FPT, FPTs,
  Fauchald, Pinaud and Tveraa, a NOTE in R CMD check *[check NOTE]*

### Speed

- [ ] `3a96ca0` · `fpt_cpp()` — no check for user interrupts, in a loop that
  could run for an hour on a long track *[usability]*
- [ ] `9a5bede` · `track_fpt_profile()` — the rows of each group were found by
  comparing every event with each group, in time proportional to groups ×
  events: 5× faster with 2,280 tracks (3.30 → 0.65 s), unchanged with few
  groups *[speed]*

### Optional branch `codereview_fpt_speedup`

- [ ] `1045a66` · `fpt_cpp()` — the search for the crossing of a circle
  checked every location until the track left the circle, so the run time
  grew with the square of the length of a track for circles left late or
  never, as is the largest default radius: blocks of 16, 256, ... locations
  whose bounding box lies inside the circle are now skipped in one step, with
  identical results *[speed]*
- [ ] `968c604` · `fpt_cpp()` — the first version made small radii 10%
  slower; the 32 locations next to each location are now checked one by one,
  and blocks are tried from the smallest up: no slowdown, 9× faster on the
  72k-fix track *[speed]*

## Findings not fixed

### Decision needed: default radii and suggested scale

- **Decision needed:** the default radii (`fpt_default_radii()`) run from the
  median non-zero step to the diagonal of the bounding box of the largest
  track, pooled over all tracks.
  - The lower end lies where the documentation itself says the radii are not
    informative (within a step, the FPT reflects the speed of the step). With
    the default `method = "first"`, the suggestion is one of the first 5 of
    the 50 radii (within about twice the median step) for 5 of 6 Argos
    albatrosses, 5 of 10 wandering albatrosses, 3 of 4 fishers and 3 of 4
    wild boar; for one fisher it is the second radius (33 m, the scale of GPS
    error at 2-minute fixes), on a profile that otherwise declines steadily.
  - The upper end is never left: no event has an FPT at the largest radius,
    and up to 35 of the 50 radii have no variance per track (e.g. 3 for the
    pelican, 3-10 for the buffalo, 21-35 for 4 of the 9 raw shag tracks).
    Without the optional speed-up, it also makes every event scan the whole
    track.
  - Pooling over tracks lets one track set the range for all: in the raw shag
    data (before cleaning), outliers 9,000 km away gave radii up to 9,098 km
    for birds that forage within 60 km.
  - Options: start at a few median steps; end at about half the diagonal;
    compute the range per track or group. Recommendation: per group, from 2
    median steps to half the diagonal of its bounding box.
- **Decision needed:** no minimum number of events behind a peak. The variance
  at a radius left by few events is noise, and `method = "steep"` picks it:
  peaks backed by 2-27 events for all 4 wild boar, a coati, a jaguar and a
  wandering albatross, and 7.6-30 km for the buffalo, whose median profile has
  a clear peak at about 3 km, near which "first" (1.5-3.6 km) and "max"
  (2.8-7.6 km) fall. Options: a
  `min_valid` argument (e.g. 30 events, or a fraction of the events), with the
  radii below it drawn in grey by `autoplot()`.
- **Decision needed:** the default `method = "first"`, which, with the
  default radii, returns the step-length artefacts above. "max" picked the
  visible peak of the buffalo and is less sensitive to the lower end; the
  choice depends on the decision on the radii.
- **Decision needed:** whether to merge `codereview_fpt_speedup` (above).

### Memory

- `track_fpt_profile()` keeps the whole events × radii matrix of FPTs and two
  copies of it (log, squares): 10 million events × 50 radii is 4 GB per copy.
  The variances could be accumulated per track in C++ instead.

### Usability and documentation

- After `tt_split_trips(complete = FALSE)`, the events of the `trip_na` dummy
  trips are not stored together, so the FPT functions stop with "x must be
  ordered by time within each track; use tt_order_time(x)" (it then works,
  but returns the events in a different order). The check could skip the
  `trip_na` events, which are ignored anyway, or the documentation could say
  so.
- A numeric time column is taken to be in seconds without warning, and a
  `units` time column (which `move2` accepts) fails with "cannot convert h
  into seconds since 1970-01-01".
- The examples use `example_tt` (5 locations per track, steps of 37 km and
  more): `track_suggest_ars_scale()` returns `NA` for every track, and the
  profile is flat at 50 and 100 km. An example (or an article) on the shags or
  the buffalo would show a real profile and peak.
- Minor: "the median distance between consecutive locations" is the median of
  the non-zero steps (71% of the steps of the 4-second albatross are zero);
  the test title "for any order of the radii" is not tested (and
  `fpt_matrix()` needs increasing radii); `n_valid` is a double rather than an
  integer.
