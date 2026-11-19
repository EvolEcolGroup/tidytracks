# Distances with units

Arguments that are physical quantities must be `units` objects (e.g.
`as_units(50, "m")`): a plain number gives an error, rather than being read
in the units of the coordinates (the CRS), where the same number would mean
metres on one dataset, kilometres or feet on another, and degrees on
longitude/latitude data. Speeds, times and distances of the cleaning
functions already followed this rule; PR #103 (branch `kde_units`, 19 Nov
2026) extended it to the distances of the home range functions, of
`tt_split_trips()` and of `ctmm_tt_fit()`.

## Decisions

- **Plain numbers give an error, with no deprecation period** (Andrea asked
  to enforce the units, 19 Nov 2026). The error says that plain numbers are
  no longer read in the units of the coordinates. A deprecation warning that
  kept reading them in CRS units for one release was the alternative; it
  would be a one-line change in `to_crs_units()`. The deprecated `hr_kde()`
  still takes plain numbers (in CRS units), as it only exists for old code
  (Claude's choice, not yet reviewed).
- **`h` is a distance** (Andrea asked, 19 Nov). The kernel of a location at
  a distance \(d\) is \(\exp(-d^2 / (2h^2)) / (2\pi h^2)\), so \(d/h\) has no
  units and `h` is in the units of the coordinates; so is the reference
  bandwidth, sd(coordinates) × \(n^{-1/6}\).
- **Distances are converted to the units in which the computation is done**:
  - on the plane, in the units of the CRS (`to_crs_units()`): `h` and `res`
    of `hr_tt_kde()`, `res` of `hr_tt_akde()`, `n` (types `"r"` and `"a"`)
    and `buffer` of `hr_tt_locoh()`. On longitude/latitude data these are
    computed in degrees, so the arguments must be angles (e.g.
    `as_units(6, "arcmin")`); a length gives an error that suggests
    projecting `x`. Without a CRS, an error asks for one.
  - on the ellipsoid, in metres: the buffers of `tt_split_trips()` on
    longitude/latitude data (`to_metres()`), so a buffer in km works on
    both projected and unprojected data.
  - in the units of an upstream package: `uere` of `ctmm_tt_fit()` in metres
    (or a UERE object from `ctmm::uere.fit()`, used as it is), and the
    arguments passed to `move2utils` (`units_to_move2utils()`).
- **Outputs carry the units too**: the `h` and `res` columns of the tables
  of UDs (`hr_tt_kde()`, `hr_tt_akde()`, `hr_tt_akde_pop()`, `hr_tt_dbbmm()`,
  `hr_tt_dbgb()`), and the `n` column of `hr_tt_locoh()` for types `"r"`
  and `"a"`, in the units of the CRS (`with_crs_units()`; plain numbers
  without a CRS, as `sf::st_area()`). This keeps round trips working (e.g.
  `hr_tt_kde(res = ud_dbbmm$res[1])`). The cost: a table of LoCoH type
  `"k"` (plain `n`) cannot be bound to one of type `"r"` (with units).
- **`hr_tt_akde_pop()` requires `res` with units**, with no support for
  tables from earlier versions (Andrea, 19 Nov).
- **`hr_tt_locoh(buffer)` defaults to `NULL`** (no buffer) rather than 0, as
  a default with units could not be converted to degrees.
- **Counts, probabilities, ratios and statistical thresholds stay plain
  numbers**: e.g. `n` of LoCoH type `"k"` (a units object is an error),
  `levels`, `tolerance` of `hr_tt_akde()`, `window_size`, the detour and
  entropy thresholds of `move2utils`, `threshold` of
  `track_suggest_max_speed()`.
- **Output units given as a unit** (e.g. `units = "km"` of
  `event_distance()`) are explicit already, and were left as they are.

## How it works

- `to_crs_units(value, arg, crs)` (in `R/hr_tt_kde.R`): checks that `value`
  is a `units` object, converts it to `crs$ud_unit`, and returns plain
  numbers; its errors name the argument, and say when `x` is in
  longitude/latitude.
- `with_crs_units(value, crs)` (same file): the inverse, for the output
  columns.
- `to_metres(x, arg, allow_zero)` (in `R/event_flag_thin_distance.R`): a
  single positive distance in metres.
- `split_trips_buffer()` (in `R/tt_split_trips.R`) and `check_uere()` (in
  `R/ctmm_tt_fit.R`): the checks of those two functions.

## Arguments checked (audit of 19 Nov 2026)

| function | argument | quantity |
|---|---|---|
| `hr_tt_kde()` | `h`, `res` | distance (CRS units) |
| `hr_tt_akde()` | `res` | distance (metres) |
| `hr_tt_locoh()` | `n` (`"r"`, `"a"`), `buffer` | distance (CRS units) |
| `hr_tt_dbbmm()`, `hr_tt_dbgb()` | `location_error`, `res`, `time_step` | distance, time |
| `tt_split_trips()` | `buffer_trip`, `buffer_complete` | distance |
| `ctmm_tt_fit()` | `uere` | distance (metres) |
| `event_flag_mcconnell()`, `tt_clean_mcconnell()` | `max_speed` | speed |
| `event_flag_corridor()` | `speed_threshold` | speed |
| `event_flag_thin_time()`, `tt_thin_time()` | `interval`, `tolerance` | time |
| `event_flag_thin_distance()`, `tt_thin_distance()` | `distance`, `tolerance` | distance |
| `tt_regular_time()` | `interval`, `max_time_lag` | time |
| `event_flag_outliers()`, `tt_clean_outliers()` | `...` (e.g. `v_max`, `location_error`) | speed, distance, mass |

## Open questions

- Should the outputs that have no units yet get them: areas without a CRS,
  and Earth mover's distances (code review 2, `codereview_2026-10.md`)?
- The error columns of `mt_as_telemetry()` with units are passed to ctmm
  without conversion (code review 2).
