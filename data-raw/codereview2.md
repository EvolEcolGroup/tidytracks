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
  - All 1509 tests pass. The one warning, in `test_hr_tt_akde_pop.R`, was
    already there.
  - Running `roxygen2::roxygenise()` changes nothing.
  - `lintr` gives the same `object_usage_linter` false positives in the ctmm
    files as on 91cc6f3 (21, against 20 before: one more call of
    `mt_as_telemetry()`).
- NEWS.md has not been updated; see the behaviour changes below.

## Commits

### Data I/O and core utilities

- [ ] `140d0de` Fix filter_by_meta() on grouped objects (bug). It failed on
  any grouped object.
- [ ] `db4b7d1` Drop unused track id levels in tt_read_data() (bug). Factor
  ids with unused levels gave "missing value where TRUE/FALSE needed".
- [ ] `50dc44f` Print move2 objects without events without a warning (bug).
- [ ] `dac04aa` Match metadata track ids by value in tt_read_data() (bug).
  Numeric ids such as 100000 became "1e+05" and did not match the metadata,
  which was silently all NA.
- [ ] `10a5d58` Drop the geometry of sf metadata in tt_write_data() (bug).
  - The metadata CSV got an extra geometry column.
  - `combined = TRUE` failed.
- [ ] `954a831` Compare duplicated metadata columns across types in
  tt_read_data() (bug). An integer column in the events and the same values
  as a double in the metadata were kept twice, with a warning.
- [ ] `ad04794` Document all the metadata columns of example_tt (docs).
- [ ] `9c1976f` Do not drop seconds when auto-detecting date-time formats
  (bug). Values with and without seconds silently lost their seconds; they now
  give an error.
- [ ] `2f7d592` Reject metadata with more than one row per track (bug).
  `show_meta<-` and tt_read_data() accepted duplicated ids, and track_*
  functions then returned too many values.
- [ ] `a2e6308` Correct the documentation of the dots of filter_by_meta()
  (docs).

### Plotting and animation

- [ ] `267ce29` Skip events without a location in geom_event_path() (bug). Any
  empty point gave an error.
- [ ] `4f6beaa` Drop events without a location in geom_event_point() (bug).
  Animations of point layers failed to build.
- [ ] `75e1e3d` Label animate_map() frames in the time zone of the tracks
  (bug). Labels used the time zone of the R session.
- [ ] `2d07777` Fix autoplot() of a grouped tibble of UDs with id_to_plot
  (bug).
- [ ] `2ebc819` Speed up the animation wake by skipping static layers (speed).
  - Test: 40 frames over a 400 x 400 raster basemap.
  - Points: 57.7 s → 7.0 s. Paths: 46.7 s → 9.2 s.
  - Frames identical.

### McConnell cleaning, regular resampling and trip splitting

- [ ] `8576295` Filter events of each track in time order in McConnell filter
  (bug). With events not stored in time order, a spike was kept and a good
  location flagged.
- [ ] `b18dbca` Convert dates and units timestamps to seconds in McConnell
  filter (bug). Date or units time stamps were taken as seconds, so almost
  every location was flagged.
- [ ] `0c408d0` Flag endpoints with an infinite speed in McConnell endpoint
  check (bug).
- [ ] `d8106a6` Ignore events without a location in tt_regular_time() (bug).
  Any empty geometry gave an error.
- [ ] `02a00d3` Give NA for numeric columns with < 2 values in
  tt_regular_time() (bug). A column that was all NA within a track gave an
  error.
- [ ] `2eb59d8` Keep the time zone of the time stamps in tt_regular_time()
  (bug). A time zone of "" became "UTC".
- [ ] `e92ef72` Mark the last trip, not the time at the centre, incomplete
  (bug, tt_split_trips()).
- [ ] `bf6659d` Speed up interpolation of locations in tt_regular_time()
  (speed).
  - The interpolation was quadratic in the number of events.
  - 4 tracks of 5000 events: 5.7 s → 1.0 s CPU.
  - Locations differ by at most 7e-9 m; all other columns are identical.
- [ ] `a0f2ce4` Fix the McConnell reference and tt_clean_mcconnell() docs
  (docs). The paper is from 1992, not 2012.

### MCP and LoCoH

- [ ] `145f6b8` Return MCP and LoCoH home ranges in the order of the group
  keys (bug). Rows were in order of first appearance, and a per-group `n` in
  LoCoH was matched to the wrong groups.
- [ ] `f01fc47` Return empty MCPs when the locations within a level have no
  area (bug). These gave invalid polygons, or an s2 error in lon/lat.
- [ ] `38a2b17` Reject missing, empty or non-numeric levels in hr_tt_mcp
  (bug).
- [ ] `4ff6fd0` Speed up hr_tt_mcp for many groups (speed).
  - 1000 groups of 20 locations: 4.3 s → 1.0 s CPU.
  - Output identical. The one exception: with several grouping variables,
    the geometry column no longer has stray names.
- [ ] `a2b2323` Speed up hr_tt_locoh for many groups (speed). 7.5 s → 4.2 s
  CPU; output identical.

### Event and track metrics

- [ ] `055104e` Return no distances or speeds for a move2 object without
  events (bug).
- [ ] `c5a0cc1` Skip events without a location in track_tot_distance() (bug).
  The leg across an event without a location was lost.
- [ ] `9c6d632` Use track_tot_distance() for the distance in
  track_summary_stats() (bug).
  - It failed with events without a location, and with grouped input.
  - Its distance did not match track_tot_distance().
- [ ] `442918e` Keep the type of the track ids in track_summary_stats() (bug).
  Integer ids gave an error.
- [ ] `a0ecba5` Use the first located event as default centre in
  track_summary_stats() (bug).
- [ ] `7fecec0` Use geodesic distances from the centre in
  track_summary_stats() (bug). The results depended on `sf_use_s2()`.
- [ ] `63994e9` Handle tracks without any location in track_summary_stats()
  (bug).
- [ ] `5af4b60` Speed up track_summary_stats() (speed). 500 tracks of 200
  events: 9.7 s → 1.8 s CPU; output identical.
- [ ] `8a1d8c9` Speed up the units conversion in event_distance() and
  event_speed() (speed). 20 tracks of 10^4 events: 8.3 s → 0.9 s CPU; output
  identical.
- [ ] `23c3028` Return degrees by default from event_azimuth() (bug). It
  returned radians, although the docs say degrees.
- [ ] `9c51314` Allow events without a location in event_azimuth() (bug).
- [ ] `9227e27` Return the lines of track_lines() in the order of the
  metadata (bug). The lines could belong to the wrong rows.
- [ ] `68a2e96` Speed up track_summary_health() (speed). 4.4 s → 0.5 s CPU;
  output identical.

### ctmm and AKDE

- [ ] `f2a61a1` Reject column weights with method = "pkde" in
  hr_tt_akde_pop() (bug). ctmm silently replaced the weights by optimised
  ones, or failed if a weight was 0.
- [ ] `6dfe0c5` Give units to all time scales in ctmm_tt_summary() (bug). The
  `tau` and `circle` columns of OUf models had no units.
- [ ] `5e11214` Restore the digits.secs option changed by ctmm in
  mt_as_telemetry() (bug).
- [ ] `15ad472` Calibrate the location error in hr_tt_akde() as when fitting
  (bug).
  - hr_tt_akde() and hr_tt_akde_pop() lost the calibration given with
    `uere` in ctmm_tt_fit().
  - Example: a 95% area of 74.7 km² instead of 69.1 km².
- [ ] `3e2138c` Pass the time to fix to ctmm in mt_as_telemetry() (bug).
  `timeout` had no effect.

### move2utils wrappers and bridge

- [ ] `9e0bafa` Keep the names of per-track values converted for move2utils
  (bug). A named per-track `mass` was rejected as ambiguous.
- [ ] `1424762` Skip tracks too short for the outlier method in
  event_flag_outliers (bug). Any track with fewer than 10 located events made
  the default method fail for the whole call. Such tracks now give a warning
  and their events are kept.
- [ ] `ca6bec2` Match a state given per event to the events passed to
  move2utils (bug).
- [ ] `d05ef57` Pass dates to move2utils as date-times (bug). Date time
  columns were read as days, so thin_time and the speed methods were wrong.
- [ ] `c700f19` Speed up the move2utils wrappers when no event is dropped
  (speed).
  - 5 tracks of 20000 events: detour 1.6 s → 0.9 s, thin_distance 1.1 s →
    0.8 s CPU.
  - Output identical.

### dBBMM, UD levels and UD overlap

- [ ] `5d6c384` Reject unused arguments in hr_tt_ud_overlap() for two UDs
  (bug). `hr_tt_ud_overlap(ud_a, ud_b, "vi")` silently returned the
  Bhattacharyya affinity.
- [ ] `8a5c013` Replace missing location errors within each track in
  hr_tt_dbbmm() (bug). They were replaced by the median of all tracks, unlike
  move2utils.

### KDE and UD utilities

- [ ] `1f1845b` Close isopleths along the edges of the grid (bug). Isopleths
  cut by the grid edge were wrong and invalid, e.g. a 95% area of 31,400 m²
  instead of 450,000 m².
- [ ] `f9f884e` Ignore duplicated levels when computing isopleths (bug).
- [ ] `1b40d77` Wrap rasters assigned to a PackedSpatRaster_list with [<-
  (bug). Saved objects could no longer be read.
- [ ] `e4eb5e5` Combine PackedSpatRaster_list objects with c() (bug).
- [ ] `2d05a28` Reject KDE grids beyond the reach of a group's kernels (bug).
  The UD was silently NaN.
- [ ] `7f35cd1` Print missing elements of a PackedSpatRaster_list (bug).
- [ ] `c341141` Sum UDs estimated with different bandwidths (bug). For
  example, `hr_tt_ud_sum()` failed after `hr_tt_kde(h = "h_ref_indiv")`.
- [ ] `c855aab` Return the groups of hr_tt_kde() in the order of the group
  keys (bug).

## Behaviour changes (candidates for NEWS.md)

- **Row order:**
  - hr_tt_kde(), hr_tt_mcp() and hr_tt_locoh() return groups in group-key
    order, as hr_tt_akde() and hr_tt_dbbmm() do.
  - For ungrouped data, that is the order of the track ids, not the order of
    the metadata.
  - track_lines() returns tracks in metadata order.
- event_azimuth() returns degrees by default.
- track_summary_stats():
  - It keeps the type of the track ids (factor or integer).
  - Distances from the centre are geodesic, whatever `sf_use_s2()` is.
- track_tot_distance() skips events without a location.
- Errors that used to be silent:
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

## Found but not fixed (need a decision)

### I/O

- tt_write_data() writes NA coordinates for events without a location, but
  tt_read_data() rejects them, so the round trip fails.
- sf-class metadata breaks as_event_column() and
  `as.data.frame(include_meta = TRUE)`.
- tt_drop_units() ignores the metadata.
- tt_write_data() silently drops units.
- Metadata ids that match no track are silently left as NA.
- Date-time auto-detection ignores time-zone offsets.

### Metrics

- vignettes/tidytracks.Rmd (about line 474) says that track_summary_stats()
  uses Euclidean distances on unprojected data, but they are geodesic.
- track_summary_health():
  - It returns plain seconds, although the docs say units.
  - It counts events without a location.
- event_speed() gives negative speeds for events not in time order.
- event_azimuth() fails for projected CRS.

### Cleaning

- tt_regular_time() stops the whole call when one track has a single
  location or never moves.
- `snap_times` snaps to UTC boundaries.
- event_flag_mcconnell() reads numeric time stamps as seconds.
- tt_split_trips():
  - It gives an unclear error without a CRS.
  - A buffer without units is taken as CRS units.
  - It overwrites existing `trip_id`/`trip_type` columns.

### move2utils

- Upstream, `mt_clean_track()` ignores the entropy, gap and persistence
  thresholds on multi-track input.
- `flag_action = "interpolate"` also interpolates events that had no location
  before cleaning, while the docs say only flagged events are replaced.
- Numeric (non date-time) time columns are read as seconds.

### KDE

- hr_tt_kde():
  - The default bbox fails when all locations share an x or a y.
  - In lon/lat it can go beyond ±90°/±180°.
  - `h` and `res` cannot be units objects.
  - `levels` with NA gives an unclear error.
  - There is no warning when the UD is cut by the grid.
- hr_tt_ud_sum() on a list advises hr_tt_ud_unwrap(), which only takes
  tables.

### MCP and LoCoH

- r- and a-LoCoH sort hulls by area, as amt does. Getz et al. (2007) and
  adehabitatHR sort them by number of locations. In one example the 50% area
  is about 143,000 m² instead of about 249,000 m².
- The MCP of lon/lat data is computed in planar degrees.
- Areas have no units without a CRS.

### dBBMM and overlap

- `cond_level` rescales the masked UDs, unlike the conditional overlaps of
  adehabitatHR.
- event_ud_level() uses a single-row UD table for all events, whatever their
  id.
- The table method of hr_tt_ud_overlap() rejects factor ids.
- Earth mover's distances have no units.
- Upstream, the dBGB C code puts mass beyond the grid in the wrong cells. The
  2-cell margin of hr_tt_dbbmm() avoids this, so it must not be reduced.

### ctmm

- An exactly duplicated event gives a degenerate fit, because `tt_row_index`
  stops ctmm from dropping it.
- `timeout`/`dt.hot` cannot reach the fit through ctmm_tt_fit() and
  hr_tt_akde().
- hr_tt_akde() rows are in group-key order, while ctmm_tt_fit() rows are in
  metadata order.
- Error columns with units are passed to ctmm without conversion.
- pkde ignores numeric weights: a ctmm bug, worth reporting upstream.

### Plotting

- geom_track_path() draws nothing for a track with one location.
- autoplot():
  - A numeric `id_to_plot` is always taken as row positions.
  - Panels are not labelled.
- animate_map():
  - It overwrites the title.
  - A `label_format` with quotes or braces breaks the label.
- shadow_wake_build() ignores `wrap = TRUE`; this is not reachable from
  animate_map().
