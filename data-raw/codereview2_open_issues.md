# Code review 2: open issues

Issues found in the review of the package at `move2utils` (91cc6f3) that
were not fixed, as they need a decision. They were moved here from
[codereview2.md](codereview2.md), for later checks and thinking.

## I/O

- tt_write_data() writes NA coordinates for events without a location, but
  tt_read_data() rejects them, so the round trip fails.
- tt_drop_units() ignores the metadata.
- tt_write_data() silently drops units.
- Metadata ids that match no track are silently left as NA.
- Date-time auto-detection ignores time-zone offsets.

## Metrics

- event_azimuth() fails for projected CRS.

## Cleaning

- tt_regular_time() stops the whole call when one track has a single
  location or never moves.
- `snap_times` snaps to UTC boundaries.
- event_flag_mcconnell() reads numeric time stamps as seconds.
- event_flag_mcconnell() can never flag the first two or last two
  locations of a track (as in the original algorithm), even with
  `check_first_last = TRUE`. When one of them is an outlier, good
  locations next to it are flagged instead. In the operations benchmark
  (1,000 tracks of 100 locations), 6 such outliers were missed and 37 good
  locations flagged; with the outlier second to last, up to 11 good
  locations in one track. This may deserve a note in the docs, or a
  different default.
- tt_split_trips():
  - It gives an unclear error without a CRS.
  - A buffer without units is taken as CRS units.
  - It overwrites existing `trip_id`/`trip_type` columns.

## move2utils

- Upstream, `mt_clean_track()` ignores the entropy, gap and persistence
  thresholds on multi-track input.
- `flag_action = "interpolate"` also interpolates events that had no location
  before cleaning, while the docs say only flagged events are replaced.
- Numeric (non date-time) time columns are read as seconds.

## KDE

- hr_tt_kde():
  - The default bbox fails when all locations share an x or a y.
  - In lon/lat it can go beyond ±90°/±180°.
  - `h` and `res` cannot be units objects.
  - `levels` with NA gives an unclear error.
  - There is no warning when the UD is cut by the grid.
- hr_tt_ud_sum() on a list advises hr_tt_ud_unwrap(), which only takes
  tables.

## MCP and LoCoH

- r- and a-LoCoH sort hulls by area, as amt does. Getz et al. (2007) and
  adehabitatHR sort them by number of locations. In one example the 50% area
  is about 143,000 m² instead of about 249,000 m².
- The MCP of lon/lat data is computed in planar degrees.
- Areas have no units without a CRS.

## dBBMM and overlap

- `cond_level` rescales the masked UDs, unlike the conditional overlaps of
  adehabitatHR.
- event_ud_level() uses a single-row UD table for all events, whatever their
  id.
- The table method of hr_tt_ud_overlap() rejects factor ids.
- Earth mover's distances have no units.
- Upstream, the dBGB C code puts mass beyond the grid in the wrong cells. The
  2-cell margin of hr_tt_dbbmm() avoids this, so it must not be reduced.

## ctmm

- An exactly duplicated event gives a degenerate fit, because `tt_row_index`
  stops ctmm from dropping it.
- `timeout`/`dt.hot` cannot reach the fit through ctmm_tt_fit() and
  hr_tt_akde().
- Error columns with units are passed to ctmm without conversion.
- pkde ignores numeric weights: a ctmm bug, worth reporting upstream.

## Plotting

- geom_track_path() draws nothing for a track with one location.
- autoplot():
  - A numeric `id_to_plot` is always taken as row positions.
  - Panels are not labelled.
- animate_map():
  - It overwrites the title.
  - A `label_format` with quotes or braces breaks the label.
- shadow_wake_build() ignores `wrap = TRUE`; this is not reachable from
  animate_map().
