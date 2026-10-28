# Changelog

## tidytracks (development version)

### New features

- New interface to the package `ctmm`, to fit continuous-time movement
  models to tibbles of tracks (see the new article “Movement models with
  ctmm”). This includes the new functions:
  [`mt_as_telemetry()`](https://evolecolgroup.github.io/tidytracks/dev/reference/mt_as_telemetry.md),
  [`ctmm_tt_fit()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_fit.md),
  [`ctmm_tt_summary()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_summary.md),
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md),
  and
  [`hr_tt_akde_pop()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde_pop.md)
- [`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)
  now works with tables of UDs from methods other than
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md),
  such as
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
  and
  [`hr_tt_dbbmm()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md)
  (it previously required the column `h`), and keeps the parameters of
  the method (e.g. `window_size` and `margin`).
- [`hr_tt_locoh()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_locoh.md),
  a fast implementation to estimate home ranges with local convex hulls
  (LoCoH).
- [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  gains a `method` argument. Its new default, `"binned"`, bins the
  locations onto the grid and then smooths them with the kernel, which
  is much faster for many locations (see the article “Benchmarking home
  ranges against amt and adehabitatHR”).
- New
  [`track_tot_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/track_tot_distance.md)
  to compute the total distance travelled along each track, with a
  `units` argument to choose the output units.
- tidytracks can now use the methods of `move2utils`, a suggested
  package installed from GitHub with
  `remotes::install_github("move2universe/move2utils")`, through
  wrappers that follow the tidytracks conventions: physical quantities
  are given as `units` objects, and events without a location are
  allowed. Projected coordinates must be in metres, as `move2utils`
  assumes.
  - [`track_suggest_max_speed()`](https://evolecolgroup.github.io/tidytracks/dev/reference/track_suggest_max_speed.md)
    suggests a maximum speed for each track from a break in the
    distribution of the speeds of its steps.
  - [`event_flag_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_outliers.md)
    and
    [`tt_clean_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_outliers.md)
    detect outliers with the methods of `move2utils` (its combined
    `mt_clean_track()` by default, or its speed cap, detour, Brownian
    bridge or probability methods), most of which choose their
    thresholds from the data.
    [`tt_clean_outliers()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_outliers.md)
    removes the outliers, or sets or interpolates their location, as
    [`tt_clean_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_mcconnell.md)
    does.
  - [`event_flag_thin_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_thin_time.md)
    and
    [`tt_thin_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_thin_time.md)
    thin tracks to a time interval (within a tolerance), keeping as many
    of the original events as possible.
  - [`event_flag_thin_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_thin_distance.md)
    and
    [`tt_thin_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_thin_distance.md)
    thin tracks by the distance travelled along them.
  - [`event_flag_corridor()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_corridor.md)
    flags the steps that are part of movement corridors (fast movement
    in a consistent direction).
  - [`hr_tt_dbbmm()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md)
    and
    [`hr_tt_dbgb()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md)
    estimate the utilisation distribution of each track with a dynamic
    Brownian bridge movement model or a dynamic bivariate Gaussian
    bridge, returning an `hr_tt_ud_tbl` that works with the other
    `hr_tt_ud_*()` functions. They require data in a projected
    coordinate reference system in metres. By default, the grid is
    chosen from the extent and width of the bridges (and differs from
    the grid of
    [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md));
    a given grid is checked to contain all the bridges.
  - [`event_ud_level()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_ud_level.md)
    returns the isopleth level of each event in a utilisation
    distribution (e.g. in the UD of its own track).
  - `hr_tt_ud_overlap(method = "earth_mover_sinkhorn")` computes a fast
    approximation of the Earth Mover’s Distance.
  - The new article “Using move2utils with tidytracks”, on the package
    website, shows these functions in use.
  - [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md),
    [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md),
    [`hr_tt_locoh()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_locoh.md),
    [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md),
    [`hr_tt_dbbmm()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md)
    and
    [`hr_tt_dbgb()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_dbbmm.md):
    Ungrouped data return the tracks in the order of the metadata.
    Per-group values (h, bbox, res, n) are matched in that same order.
    Before, they were matched in the order of the sorted track ids.
    Grouped data return the groups in the order of their keys.
  - [`event_azimuth()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_azimuth.md)
    returns degrees by default, as documented.
  - [`track_summary_health()`](https://evolecolgroup.github.io/tidytracks/dev/reference/track_summary_health.md):
    It returns the sampling interval and the duration as units, in
    seconds, and it does not count events without a location.
  - [`event_speed()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_speed.md)
    gives an error for events not ordered by time, pointing to
    [`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md).
  - `sf` metadata: It is stored as a plain table, with its geometry kept
    as an sfc column. A metadata column called like the geometry of the
    events is renamed, e.g. to geometry.meta.
  - Some invalid inputs that were silently accepted now give an error,
    e.g. duplicated track ids in the metadata.
- Speed improvements (same results) for
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md),
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  and
  [`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md).

### Documentation

- New article, “Benchmarking home ranges against amt and adehabitatHR”,
  which compares the time taken by the MCP, KDE and LoCoH estimators of
  tidytracks, amt and adehabitatHR on tracks simulated with amt, and
  checks that they give the same home ranges.
- The new article “Reading and cleaning data”, on the package website,
  shows how to read tracking data (including date-times in different
  formats), and how to clean them step by step: removing locations at
  null island, duplicated records and outliers, interpolating missing
  locations, and resampling tracks to a regular interval.

## tidytracks 0.2.1

### Bug fixes

- `hr_tt_kde(h = "h_ref_indiv")` no longer assigns the bandwidths to the
  wrong groups when the tracks are not stored in the order of the
  groups.
- [`tt_split_trips()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_split_trips.md)
  no longer uses the centre of another track, or mislabels events, when
  the events are not in the same track order as the metadata, are
  interleaved, or are not ordered by time.
- [`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_mcconnell.md)
  and
  [`tt_clean_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_clean_mcconnell.md)
  no longer run forever when a track contains a duplicated record or an
  event without a location.
- [`tt_read_data()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_read_data.md)
  reads dates with 2-digit years correctly (e.g. `15/01/24` was read as
  24 January of year 15), and joins metadata with numeric track ids.
- `hr_tt_ud_overlap(method = "udoi")` computes the UDOI of Fieberg &
  Kochanny (2005), as `adehabitatHR` does; the previous values depended
  on the resolution of the grid.
- [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)
  gives an error, instead of an overlap of 0, when the isopleth used
  with `cond_level` (or for the UDOI) contains no cells of the grid,
  i.e. when a single cell holds more than that proportion of a UD.
- [`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md)
  keeps holes in isopleths instead of filling them in.
- [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  and
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md)
  give an informative error for a grouping with groups without events
  (e.g. from grouping by a factor with unused levels with
  `.drop = FALSE`), showing how to remove them;
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  failed with “subscript out of bounds”, and
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md)
  ignored them.
- [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  returns isopleths (when `levels` is set) of class `hr_tt_poly_tbl`, as
  [`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md)
  does.
- [`track_duration()`](https://evolecolgroup.github.io/tidytracks/dev/reference/track_duration.md)
  and
  [`track_summary_health()`](https://evolecolgroup.github.io/tidytracks/dev/reference/track_summary_health.md)
  return the tracks in the order of the metadata.
- Functions work with geometry columns that are not called `geometry`.
- [`tt_split_trips()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_split_trips.md),
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  and
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md)
  handle events without a location, and
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
  and
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md)
  handle groups with few locations.
- [`tt_regular_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_regular_time.md)
  places interpolated points of projected tracks correctly, keeps the
  type of track ids and non-syntactic column names, and gives
  non-numeric columns the value of the observation at the last time.
- [`tt_write_data()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_write_data.md)
  writes times in UTC, with fractional seconds, so that they are not
  shifted when read back with
  [`tt_read_data()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_read_data.md).
- [`event_distance()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_distance.md),
  [`event_speed()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_speed.md)
  and
  [`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_flag_mcconnell.md)
  give an informative error for objects without a CRS.

## tidytracks 0.2.0

- Rename functions to `hr_tt_` prefix to avoid name clashes with other
  packages. (NOTE the old names are still available for backwards
  compatibility, but will be deprecated in future releases.)
- Allow group specific grids for
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
- Add earth mover distance to
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)
- Ensure that all `track_*` functions return values in the same order as
  in the metadata.

## tidytracks 0.1.0

- Optimisation for `hr_tt_` functions and UD raster storage in tibbles
  to improve speed of
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)
- Minor bug fixes and documentation updates.
- Implement
  [`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)
  to sum multiple UDs.

## tidytracks 0.0.1

- Initial public release.
