# tidytracks (development version)

## New features

* New interface to the package `ctmm`, to fit continuous-time movement models
  to tibbles of tracks (see the new article "Movement models with ctmm"):
  * `mt_as_telemetry()` converts a `move2` object into a list of `ctmm`
    `telemetry` objects (the reverse of `move2::mt_as_move2()`).
  * `ctmm_tt_fit()` fits a movement model to each track (by default, selecting
    the best model), and returns a table of models with one row per track, in
    the order of the metadata.
  * `ctmm_tt_summary()` returns the parameters of the models (e.g. home range
    area and crossing time), with confidence intervals.
  * `hr_tt_akde()` estimates home ranges with autocorrelated kernel density
    estimation (AKDE), using the fitted models. The UDs are returned as an
    `hr_tt_ud_tbl`, so that they can be used with the other `hr_tt_`
    functions.
* `hr_tt_ud_sum()` works with tables of UDs without a bandwidth column `h`.

# tidytracks 0.2.1

## Bug fixes

* `hr_tt_kde(h = "h_ref_indiv")` no longer assigns the bandwidths to the wrong
  groups when the tracks are not stored in the order of the groups.
* `tt_split_trips()` no longer uses the centre of another track, or mislabels
  events, when the events are not in the same track order as the metadata, are
  interleaved, or are not ordered by time.
* `event_flag_mcconnell()` and `tt_clean_mcconnell()` no longer run forever
  when a track contains a duplicated record or an event without a location.
* `tt_read_data()` reads dates with 2-digit years correctly (e.g. `15/01/24`
  was read as 24 January of year 15), and joins metadata with numeric track
  ids.
* `hr_tt_ud_overlap(method = "udoi")` computes the UDOI of Fieberg & Kochanny
  (2005), as `adehabitatHR` does; the previous values depended on the
  resolution of the grid.
* `hr_tt_ud_overlap()` gives an error, instead of an overlap of 0, when the
  isopleth used with `cond_level` (or for the UDOI) contains no cells of the
  grid, i.e. when a single cell holds more than that proportion of a UD.
* `hr_tt_ud_iso()` keeps holes in isopleths instead of filling them in.
* `hr_tt_kde()` and `hr_tt_mcp()` give an informative error for a grouping
  with groups without events (e.g. from grouping by a factor with unused levels
  with `.drop = FALSE`), showing how to remove them; `hr_tt_kde()` failed with
  "subscript out of bounds", and `hr_tt_mcp()` ignored them.
* `hr_tt_kde()` returns isopleths (when `levels` is set) of class
  `hr_tt_poly_tbl`, as `hr_tt_ud_iso()` does.
* `track_duration()` and `track_summary_health()` return the tracks in the
  order of the metadata.
* Functions work with geometry columns that are not called `geometry`.
* `tt_split_trips()`, `hr_tt_kde()` and `hr_tt_mcp()` handle events without a
  location, and `hr_tt_kde()` and `hr_tt_mcp()` handle groups with few
  locations.
* `tt_regular_time()` places interpolated points of projected tracks
  correctly, keeps the type of track ids and non-syntactic column names, and
  gives non-numeric columns the value of the observation at the last time.
* `tt_write_data()` writes times in UTC, with fractional seconds, so that they
  are not shifted when read back with `tt_read_data()`.
* `event_distance()`, `event_speed()` and `event_flag_mcconnell()` give an
  informative error for objects without a CRS.

# tidytracks 0.2.0

* Rename functions to `hr_tt_` prefix to avoid name clashes with other packages.
  (NOTE the old names are still available for backwards compatibility, but will 
  be deprecated in future releases.)
* Allow group specific grids for `hr_tt_kde()`
* Add earth mover distance to `hr_tt_ud_overlap()`
* Ensure that all `track_*` functions return values in the same order as in the
  metadata.

# tidytracks 0.1.0

* Optimisation for `hr_tt_` functions and UD raster storage in tibbles to improve 
  speed of `hr_tt_ud_overlap()` 
* Minor bug fixes and documentation updates.
* Implement `hr_tt_ud_sum()` to sum multiple UDs.

# tidytracks 0.0.1

* Initial public release.
