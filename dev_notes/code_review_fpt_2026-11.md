# Code review of the FPT functions (branch `fpt`), November 2026

## Summary

- **Branch reviewed:** `fpt`, commit `fea842f` ("First attempt to implement
  First Passage Time (FPT) functionality"), by Lizzie Pearmain, i.e. the
  changes from its parent `f841a16` (the `inbound` work, merged into `dev` as
  #91): the new `event_fpt()`, `track_fpt_profile()` (with an `autoplot()`
  method), `track_suggest_ars_scale()` and `src/fpt.cpp`.
- **Fixes:** 7 commits on the local branch `codereview_fpt`, from `fea842f`
  (5 bugs, 1 documentation fix, 1 R CMD check NOTE), plus this report.
- **Speed-up:** `codereview_fpt_speedup`, from `9a5bede`, 2 commits: an
  exact speed-up of the search in `fpt_cpp()`, 9× faster on a 72k-fix track
  and about linear rather than quadratic in the length of a track, with
  identical results and no slowdown elsewhere. Merged into `codereview_fpt`
  (`411b28b`) on Andrea's decision, 16 November 2026.
- **New defaults:** 3 commits, decided by Andrea on 16 November 2026 after
  the review: radii chosen per track or group, a minimum proportion of
  locations per radius, and the highest peak as the default; plus new
  examples and an article ("Area-restricted search with first passage
  time"). A second verifying agent then found a bug in the grouped profiles
  introduced by the first of these commits, and smaller issues: 6 follow-up
  commits, and a third agent 3 more.
- **Findings not fixed:** 5, none needing a decision.
- **Headline:** the FPTs are right. They equal `adehabitatLT::fpt()` exactly
  (same values, same missing values) on 11 real datasets, 1,655,175
  event × radius values. The problems were in the scale suggestion, in the
  speed on long tracks or many tracks, and in the defaults.
- Nothing is pushed.

## Verification

All on the laptop (laptopX1), 16 November 2026.

| Check | Where | Result |
|---|---|---|
| R CMD check (options as below) | `codereview_fpt` at `a27a29b` (later commits change only documentation and `dev_notes/`), built from a clean copy | Status: OK; 1,694 tests passed, 0 failed, 0 warnings, 0 skipped; examples and spelling OK. `lint_package()` found one long line, rewrapped in `45edbf2` (documentation only): 0 lints at `45edbf2` |
| R CMD check (options as below) | `codereview_fpt` at `3a89c76`, built from a clean copy | Status: OK; 1,692 tests passed, 0 failed, 0 warnings, 0 skipped; examples and spelling OK |
| R CMD check (options as below) | `codereview_fpt` at `115fce9` | Status: OK; 1,683 tests passed, 0 failed, 0 warnings, 0 skipped; examples and spelling OK |
| Article rendered (`rmarkdown::render()`) | `a27a29b` | renders in about 6 s; text matches the output |
| New defaults verified by a separate agent | `fae2f72` to `115fce9` | the tests of `fae2f72`, `df5e770` and `c5f4e4f` fail before and pass after; found the grouping bug of `fae2f72` and the issues fixed in `4863bf7` to `3a89c76` |
| Follow-ups verified by a separate agent | `4863bf7` to `3a89c76` | the tests of `4863bf7`, `49009e8` and `74ae17c` fail before and pass after; grouped profiles of the 6 ctmm buffalo (by season, by blocks of 37 locations) equal `var(log(event_fpt()))` per group (largest difference 9e-14); profiles of whole tracks identical to `115fce9`; found the issue fixed in `79a4be6` and the wording fixed in `f5ec019` and `a27a29b` |
| R CMD check (options as in the next row) | `codereview_fpt` at `411b28b` (after merging the speed-up), built from a clean copy | Status: OK; 1,656 tests passed, 0 failed, 0 warnings, 0 skipped |
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
- New defaults (`fae2f72`, `df5e770`, `c5f4e4f`, with `4863bf7`): the default radii differ
  between tracks (or groups); profiles gain the column `enough_events`; tracks
  without default radii get one row of missing values and a warning, instead
  of an error for the whole object; `track_suggest_ars_scale()` ignores radii
  with fewer than half of the locations of the track, and returns the highest
  peak. Profiles with radii given by the user are unchanged, except for the
  new column.
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

### Speed-up (branch `codereview_fpt_speedup`, merged in `411b28b`)

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

### New defaults (decided by Andrea, 16 November 2026)

- [ ] `fae2f72` · `track_fpt_profile()` — the default radii ran from the
  median step to the diagonal of the largest track, pooled over tracks: the
  lower end was within a step for a third of the locations (the FPT is then
  the radius over the speed of the steps), giving first peaks at the scale of
  the steps (33-47 m for fishers with 2-minute fixes); the upper end was
  never left (2-35 of 50 radii without a variance per track); and one track
  set the range of all. Now 50 radii per track or group, from twice the
  median non-zero step to half the diagonal of its largest track
  *[wrong suggestions]*
- [ ] `df5e770` · `track_fpt_profile()`, `track_suggest_ars_scale()`,
  `autoplot()` — no minimum number of locations behind a radius: `"steep"`
  picked peaks backed by 2-27 locations, and `"max"` a spike at 15 km for
  buffalo Mvubu (peak at 3 km), where the locations with an FPT fall from
  1,998 to 772. New `min_prop_valid` (default 0.5) and column
  `enough_events`; radii below it are ignored, and drawn dashed. A proportion
  rather than a count (30), decided by Andrea: on 34 real tracks it removed
  the end-of-range spikes and changed nothing else *[wrong suggestions]*
- [ ] `c5f4e4f` · `track_suggest_ars_scale()` — the default `"first"` picked
  small bumps before the main peak (buffalo Pepper: 0.96 km, peak at 7.4 km);
  the default is now `"max"` *[wrong suggestions]*
- [ ] `64bddb3` · examples — `example_tt` (5 locations per track) gave `NA`
  suggestions and flat profiles; the examples now use two buffalo of `ctmm`
  *[documentation]*
- [ ] `115fce9` · new article "Area-restricted search with first passage
  time", on the four buffalo of the ctmm article: the FPT, the profiles, the
  default radii, `min_prop_valid`, the choice of peak, and the options
  *[documentation]*

### Follow-ups found by the verifying agent

- [ ] `4863bf7` · `track_fpt_profile()` — `fae2f72` computed the FPT of a
  group from its own events of each track, so a group holding part of a track
  (e.g. grouped by season) joined its pieces as if consecutive: the variance
  changed by 19% on average for the buffalo grouped by season. The FPT is
  again computed on whole tracks *[wrong results, introduced by `fae2f72`]*
- [ ] `49009e8` · `autoplot()` — failed on a profile without the column
  `enough_events` *[error]*
- [ ] `01688ac` · test of `min_prop_valid` — matched an error of the old code
  too *[test]*
- [ ] `fd53d22` · documentation of `min_prop_valid`, of tracks without usable
  events, and of the column `id` of the plot data *[documentation]*
- [ ] `74ae17c` · `track_fpt_profile()` — the warning about tracks without
  default radii lists at most 10 of them *[usability]*
- [ ] `3a89c76` · article — a `group_by(x, sex)` example that fails on these
  data, an overstated "clear peak", the `peak_width` example, and wording
  *[documentation]*
- [ ] `79a4be6` · `fpt_matrix_of_rows()` — `4863bf7` found tracks by name, so
  a track with id `""` got no FPT at all, silently; now by position
  *[wrong results, introduced by `4863bf7`]*
- [ ] `f5ec019` · documentation of the FPT within a step, and of `x`
  *[documentation]*
- [ ] `a27a29b` · article wording *[documentation]*
- [ ] `45edbf2` · a line of documentation longer than 80 characters (from
  `f5ec019`), reported by `lint_package()` *[lint]*

Correction to the message of `df5e770`: the spike of Mvubu at 15.1 km has
1,376 of 2,572 locations with an FPT; 772 is the number at the next radius
(16.4 km), whose exclusion leaves the spike as the last usable radius, which
cannot be a peak.

## Analysis behind the new defaults

On the real data of the review, with the defaults before `fae2f72`:

- The default radii ran from the median non-zero step to the diagonal of the
  bounding box of the largest track, pooled over all tracks.
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
    Before the speed-up (now merged), it also made every event scan the
    whole track.
  - Pooling over tracks lets one track set the range for all: in the raw shag
    data (before cleaning), outliers 9,000 km away gave radii up to 9,098 km
    for birds that forage within 60 km.
  - At the first default radius, about a third of the events (33-36% for
    fishers, buffalo, shags and both albatross datasets) have both their
    steps longer than the radius, so their FPT is the radius divided by the
    speed of the steps, and the variance of its log does not depend on the
    radius; a fifth still do at the fifth radius.
  - Tried (not in the package): 50 radii per track, from 2 median non-zero
    steps to half the diagonal of the track's bounding box. Radii without a
    variance drop to none for the buffalo, fishers, jaguars, coatis and both
    albatross datasets (0-8 for the cleaned shags, whose unsplit tracks
    include the colony); the "first" suggestion moves from 33-47 m to
    1.8-1.9 km for two fishers, to no peak for the fisher whose profile
    declines steadily, and from 270-290 km to 610-1,100 km for five 12-hourly
    wandering albatrosses. It does not remove the early peaks of the Argos
    albatrosses (24-63 km) or of the unsplit shags (20-80 m for most), and an
    outlier still sets the range of its own track (raw shags).
  - The range alone did not stop "first" from picking small early peaks,
    hence the two other changes.
- No minimum number of events behind a peak. The variance
  at a radius left by few events is noise, and `method = "steep"` picks it:
  peaks backed by 2-27 events for all 4 wild boar, a coati, a jaguar and a
  wandering albatross, and 7.6-30 km for the buffalo, whose median profile has
  a clear peak at about 3 km, near which "first" (1.5-3.6 km) and "max"
  (2.8-7.6 km) fall.
- The default `method = "first"` returned the step-length artefacts above.

## Findings not fixed

### Speed and memory

- Since `4863bf7`, a group runs `fpt_cpp()` on every whole track it touches,
  so grouping by a column that changes often within tracks (e.g. by day)
  repeats the FPT of each track once per group it touches. With radii given
  by the user, the FPT of each track could be computed once for all groups;
  not timed.

- `track_fpt_profile()` keeps the events × radii matrix of FPTs of a group,
  and two copies of it (log, squares): 10 million events × 50 radii is 4 GB
  per copy for a single track or group (since `fae2f72`, only one group at a
  time). The variances could be accumulated per track in C++ instead.

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
- Minor: the test title "for any order of the radii" is not tested (and
  `fpt_matrix()` needs increasing radii); `n_valid` is a double rather than an
  integer.
