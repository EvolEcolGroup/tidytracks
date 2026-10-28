# Code review 2: checklist of fixes

Full review of the package at `move2utils` (91cc6f3), split by domain. Each
fix is in its own commit on the branch `codereview2`, together with its test.
Tick each commit once it has been reviewed.

How the commits were checked:

- **Bug fixes**: the test of each commit was run on the original code (91cc6f3)
  and failed, for the reason described in the commit message, and it passes
  with the fix.
- **Speed-ups**: re-benchmarked against the parent commit, and the outputs
  were compared with `identical()`. All of them are identical, except
  `tt_regular_time()`, where locations differ by floating-point rounding only.
- **Documentation**: checked by reading the diff.
- **On the whole branch**:
  - All 1558 tests pass. The one warning, in `test_hr_tt_akde_pop.R`, was
    already there.
  - Running `roxygen2::roxygenise()` changes nothing.
  - `lintr` gives the same `object_usage_linter` false positives in the ctmm
    files as on 91cc6f3 (21, against 20 before: one more call of
    `mt_as_telemetry()`).
- NEWS.md has not been updated; see the behaviour changes below.

## Commits

### Data I/O and core utilities

- [x] `140d0de` Fix filter_by_meta() on grouped objects (bug). It failed on
  any grouped object.
- [x] `db4b7d1` Drop unused track id levels in tt_read_data() (bug). Factor
  ids with unused levels gave "missing value where TRUE/FALSE needed".
- [x] `50dc44f` Print move2 objects without events without a warning (bug).
- [x] `dac04aa` Match metadata track ids by value in tt_read_data() (bug).
  Numeric ids such as 100000 became "1e+05" and did not match the metadata,
  which was silently all NA.
- [x] `10a5d58` Drop the geometry of sf metadata in tt_write_data() (bug).
  - The metadata CSV got an extra geometry column.
  - `combined = TRUE` failed.
- [x] `954a831` Compare duplicated metadata columns across types in
  tt_read_data() (bug). An integer column in the events and the same values
  as a double in the metadata were kept twice, with a warning.
- [x] `ad04794` Document all the metadata columns of example_tt (docs).
- [x] `9c1976f` Do not drop seconds when auto-detecting date-time formats
  (bug). Values with and without seconds silently lost their seconds; they now
  give an error.
- [x] `2f7d592` Reject metadata with more than one row per track (bug).
  `show_meta<-` and tt_read_data() accepted duplicated ids, and track_*
  functions then returned too many values.
- [x] `a2e6308` Correct the documentation of the dots of filter_by_meta()
  (docs).

### Plotting and animation

- [x] `267ce29` Skip events without a location in geom_event_path() (bug). Any
  empty point gave an error.
- [x] `4f6beaa` Drop events without a location in geom_event_point() (bug).
  Animations of point layers failed to build.
- [x] `75e1e3d` Label animate_map() frames in the time zone of the tracks
  (bug). Labels used the time zone of the R session.
- [x] `2d07777` Fix autoplot() of a grouped tibble of UDs with id_to_plot
  (bug).
- [x] `2ebc819` Speed up the animation wake by skipping static layers (speed).
  - Test: 40 frames over a 400 x 400 raster basemap.
  - Points: 57.7 s → 7.0 s. Paths: 46.7 s → 9.2 s.
  - Frames identical.

### McConnell cleaning, regular resampling and trip splitting

- [x] `8576295` Filter events of each track in time order in McConnell filter
  (bug). With events not stored in time order, a spike was kept and a good
  location flagged.
- [x] `b18dbca` Convert dates and units timestamps to seconds in McConnell
  filter (bug). Date or units time stamps were taken as seconds, so almost
  every location was flagged.
- [x] `0c408d0` Flag endpoints with an infinite speed in McConnell endpoint
  check (bug).
- [x] `d8106a6` Ignore events without a location in tt_regular_time() (bug).
  Any empty geometry gave an error.
- [x] `02a00d3` Give NA for numeric columns with < 2 values in
  tt_regular_time() (bug). A column that was all NA within a track gave an
  error.
- [x] `2eb59d8` Keep the time zone of the time stamps in tt_regular_time()
  (bug). A time zone of "" became "UTC".
- [x] `e92ef72` Mark the last trip, not the time at the centre, incomplete
  (bug, tt_split_trips()).
- [x] `bf6659d` Speed up interpolation of locations in tt_regular_time()
  (speed).
  - The interpolation was quadratic in the number of events.
  - 4 tracks of 5000 events: 5.7 s → 1.0 s CPU.
  - Locations differ by at most 7e-9 m; all other columns are identical.
- [x] `a0f2ce4` Fix the McConnell reference and tt_clean_mcconnell() docs
  (docs). The paper is from 1992, not 2012.

### MCP and LoCoH

- [x] `145f6b8` Return MCP and LoCoH home ranges in the order of the group
  keys (bug). Rows were in order of first appearance, and a per-group `n` in
  LoCoH was matched to the wrong groups.
- [x] `f01fc47` Return empty MCPs when the locations within a level have no
  area (bug). These gave invalid polygons, or an s2 error in lon/lat.
- [x] `38a2b17` Reject missing, empty or non-numeric levels in hr_tt_mcp
  (bug).
- [x] `4ff6fd0` Speed up hr_tt_mcp for many groups (speed).
  - 1000 groups of 20 locations: 4.3 s → 1.0 s CPU.
  - Output identical. The one exception: with several grouping variables,
    the geometry column no longer has stray names.
- [x] `a2b2323` Speed up hr_tt_locoh for many groups (speed). 7.5 s → 4.2 s
  CPU; output identical.

### Event and track metrics

- [x] `055104e` Return no distances or speeds for a move2 object without
  events (bug).
- [x] `c5a0cc1` Skip events without a location in track_tot_distance() (bug).
  The leg across an event without a location was lost.
- [x] `9c6d632` Use track_tot_distance() for the distance in
  track_summary_stats() (bug).
  - It failed with events without a location, and with grouped input.
  - Its distance did not match track_tot_distance().
- [x] `442918e` Keep the type of the track ids in track_summary_stats() (bug).
  Integer ids gave an error.
- [x] `a0ecba5` Use the first located event as default centre in
  track_summary_stats() (bug).
- [x] `7fecec0` Use geodesic distances from the centre in
  track_summary_stats() (bug). The results depended on `sf_use_s2()`.
- [x] `63994e9` Handle tracks without any location in track_summary_stats()
  (bug).
- [x] `5af4b60` Speed up track_summary_stats() (speed). 500 tracks of 200
  events: 9.7 s → 1.8 s CPU; output identical.
- [x] `8a1d8c9` Speed up the units conversion in event_distance() and
  event_speed() (speed). 20 tracks of 10^4 events: 8.3 s → 0.9 s CPU; output
  identical.
- [x] `23c3028` Return degrees by default from event_azimuth() (bug). It
  returned radians, although the docs say degrees.
- [x] `9c51314` Allow events without a location in event_azimuth() (bug).
- [x] `9227e27` Return the lines of track_lines() in the order of the
  metadata (bug). The lines could belong to the wrong rows.
- [x] `68a2e96` Speed up track_summary_health() (speed). 4.4 s → 0.5 s CPU;
  output identical.

### ctmm and AKDE

- [x] `f2a61a1` Reject column weights with method = "pkde" in
  hr_tt_akde_pop() (bug). ctmm silently replaced the weights by optimised
  ones, or failed if a weight was 0.
- [x] `6dfe0c5` Give units to all time scales in ctmm_tt_summary() (bug). The
  `tau` and `circle` columns of OUf models had no units.
- [x] `5e11214` Restore the digits.secs option changed by ctmm in
  mt_as_telemetry() (bug).
- [x] `15ad472` Calibrate the location error in hr_tt_akde() as when fitting
  (bug).
  - hr_tt_akde() and hr_tt_akde_pop() lost the calibration given with
    `uere` in ctmm_tt_fit().
  - Example: a 95% area of 74.7 km² instead of 69.1 km².
- [x] `3e2138c` Pass the time to fix to ctmm in mt_as_telemetry() (bug).
  `timeout` had no effect.

### move2utils wrappers and bridge

- [x] `9e0bafa` Keep the names of per-track values converted for move2utils
  (bug). A named per-track `mass` was rejected as ambiguous.
- [x] `1424762` Skip tracks too short for the outlier method in
  event_flag_outliers (bug). Any track with fewer than 10 located events made
  the default method fail for the whole call. Such tracks now give a warning
  and their events are kept.
- [x] `ca6bec2` Match a state given per event to the events passed to
  move2utils (bug).
- [x] `d05ef57` Pass dates to move2utils as date-times (bug). Date time
  columns were read as days, so thin_time and the speed methods were wrong.
- [x] `c700f19` Speed up the move2utils wrappers when no event is dropped
  (speed).
  - 5 tracks of 20000 events: detour 1.6 s → 0.9 s, thin_distance 1.1 s →
    0.8 s CPU.
  - Output identical.

### dBBMM, UD levels and UD overlap

- [x] `5d6c384` Reject unused arguments in hr_tt_ud_overlap() for two UDs
  (bug). `hr_tt_ud_overlap(ud_a, ud_b, "vi")` silently returned the
  Bhattacharyya affinity.
- [x] `8a5c013` Replace missing location errors within each track in
  hr_tt_dbbmm() (bug). They were replaced by the median of all tracks, unlike
  move2utils.

### KDE and UD utilities

- [x] `1f1845b` Close isopleths along the edges of the grid (bug). Isopleths
  cut by the grid edge were wrong and invalid, e.g. a 95% area of 31,400 m²
  instead of 450,000 m².
- [x] `f9f884e` Ignore duplicated levels when computing isopleths (bug).
- [x] `1b40d77` Wrap rasters assigned to a PackedSpatRaster_list with [<-
  (bug). Saved objects could no longer be read.
- [x] `e4eb5e5` Combine PackedSpatRaster_list objects with c() (bug).
- [x] `2d05a28` Reject KDE grids beyond the reach of a group's kernels (bug).
  The UD was silently NaN.
- [x] `7f35cd1` Print missing elements of a PackedSpatRaster_list (bug).
- [x] `c341141` Sum UDs estimated with different bandwidths (bug). For
  example, `hr_tt_ud_sum()` failed after `hr_tt_kde(h = "h_ref_indiv")`.
- [x] `c855aab` Return the groups of hr_tt_kde() in the order of the group
  keys (bug).

### Order of the tracks of ungrouped data (added after the review)

For ungrouped data, the hr_tt_* estimators now return the tracks in the order
of the metadata, as the track_* functions do. Groups set by the user are still
returned in the order of their keys. Per-group values are matched to the
groups in the order in which they are returned. The tests were checked in the
same way: they fail on the code before each commit and pass with it.

- [x] `209c8f8` Return the tracks of ungrouped data from hr_tt_kde() in
  metadata order.
  - Adds the internal helper hr_group_order(), used by all five commits.
  - Per-track values of `h`, `bbox` and `res` are now matched in metadata
    order; the existing test of the bandwidths was updated.
- [x] `f2d6f63` Return the tracks of ungrouped data from hr_tt_mcp() in
  metadata order.
- [x] `77cc97f` Return the tracks of ungrouped data from hr_tt_locoh() in
  metadata order. Per-track values of `n` are matched in the same order.
- [x] `c91d64d` Return the tracks of ungrouped data from hr_tt_akde() in
  metadata order. Per-track values of `bbox` and `res` are matched in the
  same order.
- [x] `d20202e` Return the tracks of ungrouped data from hr_tt_dbbmm() in
  metadata order (also hr_tt_dbgb()). The dbbmm tests now take the UDs by
  name rather than by position.

### Metrics and documentation (added after the review)

These were checked in the same way: each test fails on the code before its
commit and passes with it.

- [x] `9a713cf` Give the times of track_summary_health() in seconds as units.
  `median_sampling_interval` and `track_duration` were plain numbers.
- [x] `71de5a2` Do not count events without a location in
  track_summary_health().
  - Failed fixes now count as missing points, which is documented.
  - A track without any location has 0 actual points and NA elsewhere.
- [x] `91effbf` Correct the distances of track_summary_stats() in the
  introduction (docs). The vignette said Euclidean; they are geodesic, in
  metres.
- [x] `f44dab9` Require events ordered by time in event_speed().
  - Events out of order silently gave speeds between the wrong events
    (negative ones for times going backwards).
  - It now gives the error of the move2utils wrappers, pointing to
    tt_order_time().

### sf metadata (added after the review)

move2 cannot join an `sf` table of metadata to the events, so
as_event_column(), `as.data.frame(include_meta = TRUE)` and track_lines()
failed with "y should not have class sf". These were checked in the same way:
each test fails on the code before its commit and passes with it.

- [x] `108a30f` Store sf metadata as a plain table in show_meta<-.
  - The geometry is kept as an `sfc` column.
  - A metadata column named like the events' geometry column (`geometry`,
    the default of sf) is renamed `geometry.meta`, with a message. Otherwise
    joining it replaced the events' geometry by `geometry.x`/`geometry.y`.
- [x] `41809ee` Join sf metadata to the events in as_event_column() and
  others. as_event_column(), as.data.frame() and track_lines() apply the same
  conversion, for metadata set without show_meta<- (e.g. with
  `move2::mt_set_track_data()`).
- [x] `b5fb39b` Describe how sf metadata is stored in the introduction (docs).
  It replaces the warning against `sf` metadata.

### Home range benchmark (added after the review)

- [ ] `7002ed4` Rerun the home range benchmark with the reviewed code.
  - Same machine (an idle i7-10510U), tidytracks 0.2.1.9004 installed with
    `R CMD INSTALL`. All 2180 areas are unchanged.
  - Times relative to the previous run: hr_tt_mcp() 0.29 to 0.61,
    hr_tt_locoh() 0.68 to 0.81, hr_tt_kde() 0.95 to 1.11. The KDE
    differences are noise: old and new code timed alternately take the
    same time. amt and adehabitatHR, whose code is unchanged, take 0.92
    to 1.16 times as long.
  - The statements of the article still hold. Also fixes a line wrap that
    Pandoc rendered as an ordered list.

### Speed with many tracks (added after the review)

Found by the operations benchmark: both functions found the events of each
track by scanning all the events, so their time grew with the number of
tracks times the total number of locations. Timed with tidytracks installed
with `R CMD INSTALL`, on 1M simulated locations. The outputs are identical to
the old code on all data sets, including events out of time order,
interleaved tracks, events without a location and metadata in another order.
With few tracks, the time is unchanged.

- [ ] `ca53fbd` Speed up event_flag_mcconnell() for many tracks (speed).
  - 10,000 tracks of 100 locations: 51.3 s → 6.4 s.
  - 1,000 tracks of 1,000 locations: 9.0 s → 4.7 s.
- [ ] `0aca17a` Speed up tt_split_trips() for many tracks (speed).
  - The rows are split by track once, and the trips of each track are built
    with `tibble::new_tibble()` rather than `tibble::tibble()`, which took
    about 1 ms per track.
  - 10,000 tracks of 100 locations: 73 s → 7.2 s.
  - 1,000 tracks of 1,000 locations: 7.8 s → 1.75 s.

## Behaviour changes (candidates for NEWS.md)

- **Row order:**
  - For ungrouped data, hr_tt_kde(), hr_tt_mcp(), hr_tt_locoh(),
    hr_tt_akde(), hr_tt_dbbmm() and hr_tt_dbgb() return the tracks in the
    order of the metadata.
  - Groups set by the user are returned in the order of their keys.
    hr_tt_kde(), hr_tt_mcp() and hr_tt_locoh() used the order in which the
    groups first appear in the events.
  - Per-group values (`h`, `bbox`, `res`, `n`) are matched to the groups in
    the order in which they are returned. For ungrouped data, this replaces
    the documented order of the track ids in hr_tt_kde(), hr_tt_locoh() and
    hr_tt_akde(): code that passes per-track values sorted by id now applies
    them to different tracks.
  - track_lines() returns tracks in metadata order.
- event_azimuth() returns degrees by default.
- track_summary_stats():
  - It keeps the type of the track ids (factor or integer).
  - Distances from the centre are geodesic, whatever `sf_use_s2()` is.
- track_tot_distance() skips events without a location.
- track_summary_health():
  - The median sampling interval and the duration are units objects, in
    seconds.
  - Events without a location are not counted, so they count as missing
    points.
- Errors that used to be silent:
  - events not ordered by time in event_speed();
  - duplicated track ids in the metadata;
  - mixed date-time formats with and without seconds;
  - column weights with `method = "pkde"`;
  - KDE grids that cannot be reached by the kernels.
- event_flag_outliers() warns about short tracks and keeps their events,
  instead of failing.
- hr_tt_dbbmm() gives move2utils' error for a track whose location errors are
  all NA.
- hr_tt_mcp() returns empty polygons for levels with no area.
- hr_tt_ud_sum() sums UDs whose method parameters differ. The parameters that
  differ become NA.
- `sf` metadata is stored as a plain table, with its geometry as an `sfc`
  column. A metadata column with the name of the events' geometry column is
  renamed with a `.meta` suffix (e.g. `geometry.meta`), with a message.

## Found but not fixed

The issues found but not fixed, which need a decision, are listed in
[codereview2_open_issues.md](codereview2_open_issues.md).
