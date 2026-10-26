# tidytracks (development version)

## New features

* tidytracks can now use the methods of `move2utils`, a suggested package
  installed from GitHub with
  `remotes::install_github("move2universe/move2utils")`, through wrappers
  that follow the tidytracks conventions: physical quantities are given as
  `units` objects, and events without a location are allowed. Projected
  coordinates must be in metres, as `move2utils` assumes.
  * `max_speed_allometric()` predicts the maximum speed of an animal from its
    body mass and mode of locomotion (Hirt et al. 2017), for use as
    `max_speed` in `event_flag_mcconnell()` and `tt_clean_mcconnell()`.
  * `track_suggest_max_speed()` suggests a maximum speed for each track from
    a break in the distribution of the speeds of its steps.
  * `event_flag_outliers()` and `tt_clean_outliers()` detect outliers with
    the methods of `move2utils` (its combined `mt_clean_track()` by default,
    or its speed cap, detour, Brownian bridge or probability methods), most
    of which choose their thresholds from the data. `tt_clean_outliers()`
    removes the outliers, or sets or interpolates their location, as
    `tt_clean_mcconnell()` does.
  * `event_flag_thin_time()` and `tt_thin_time()` thin tracks to a time
    interval (within a tolerance), keeping as many of the original events as
    possible.
  * `event_flag_thin_distance()` and `tt_thin_distance()` thin tracks by the
    distance travelled along them.
  * `event_flag_corridor()` flags the steps that are part of movement
    corridors (fast movement in a consistent direction).
  * `hr_tt_dbbmm()` and `hr_tt_dbgb()` estimate the utilisation distribution
    of each track with a dynamic Brownian bridge movement model or a dynamic
    bivariate Gaussian bridge, returning an `hr_tt_ud_tbl` that works with the
    other `hr_tt_ud_*()` functions. They require data in a projected
    coordinate reference system in metres. By default, the grid is chosen
    from the extent and width of the bridges (and differs from the grid of
    `hr_tt_kde()`); a given grid is checked to contain all the bridges.
  * `event_ud_level()` returns the isopleth level of each event in a
    utilisation distribution (e.g. in the UD of its own track).
  * `hr_tt_ud_overlap(method = "earth_mover_sinkhorn")` computes a fast
    approximation of the Earth Mover's Distance.
  * The new article "Using move2utils with tidytracks", on the package
    website, shows these functions in use.
* `hr_tt_ud_sum()` now works with tables of UDs from methods other than
  `hr_tt_kde()` (it previously required the column `h`), and keeps the
  parameters of the method (e.g. `window_size` and `margin`).
* The new article "Reading and cleaning data", on the package website, shows
  how to read tracking data (including date-times in different formats), and
  how to clean them step by step: removing locations at null island,
  duplicated records and outliers, interpolating missing locations, and
  resampling tracks to a regular interval.

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
