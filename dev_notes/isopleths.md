# Isopleths that cannot be drawn

The rule for home range polygons and isopleths: **each UD (or group) has one
row per level**. An isopleth that cannot be drawn is never dropped. Its row
gets an empty geometry, an `NA` area, and a warning that says why and what to
do. It came from #82 (PR #100, November 2026), where `hr_tt_ud_iso()` silently
dropped a level. The code is in `R/hr_tt_ud_iso.R`:
- `cud_isopleths()`, `iso_sf()` and `isopleth_table()`;
- the reasons, in `isopleths_not_drawn()` and `isopleth_not_drawn_reason()`;
- the warning, in `warn_isopleths_not_drawn()`.

The rule is also applied in `R/hr_tt_mcp.R`, `R/hr_tt_locoh.R` and
`R/hr_tt_dbbmm.R` (`with_skipped_tracks()`).

## Design decisions

| decision | alternatives considered | why | date | decided by |
|---|---|---|---|---|
| an isopleth that cannot be drawn gets a row with an empty geometry, an `NA` area, and a warning giving the reason and a remedy | an error, as `hr_tt_ud_overlap()` gives for its masks; a row with area 0 (suggested in #82) | one row per level is easier to join and plot; `NA` says the area is unknown; empty geometries plot fine with `geom_sf()` | 2026-11-16 | Andrea |
| one warning per call, one line per UD and reason, cut after 10 lines | one warning per UD | many tracks would give many warnings | 2026-11-16 | Claude |
| empty MCP and LoCoH polygons (locations on a line or at one place) get an `NA` area, not 0, with the same warning | keep area 0, without a warning | the same rule for all methods | 2026-11-16 | Claude, applying Andrea's rule |
| `hr_tt_dbbmm(levels = ...)` gives empty rows for tracks too short for `window_size`; its table of UDs still leaves them out | rows with an `NA` UD in the table of UDs | every function that takes UDs would have to handle empty UDs | 2026-11-16 | Andrea |
| MCP and LoCoH groups with fewer than three locations, and KDE groups whose UD is 0 on the grid, still give an error | empty rows with a warning | the group cannot be estimated at all | 2026-11-16 | Andrea |

## How it works

- `cud_isopleths()` records each level that it cannot draw, with a reason,
  in `not_drawn` (a data frame of `level`, `reason` and `detail`). The
  reasons are:
  - `highest_cells`: the level is below the cumulative UD of every cell;
    the detail is the smallest level that can be drawn. A cell is within
    the isopleth if its cumulative UD is at most the level, as in
    `hr_tt_ud_overlap()`.
  - `zero_level`: a 0% level.
  - `ud_no_values` and `ud_infinite`: a UD that is all `NA`, or has infinite
    values.
  - `no_contour`: the contour lines fail.
  - `no_polygon`: the lines cannot be turned into polygons.
  - `no_area`: the polygons are empty.
- `iso_sf()` builds one row per level, and reports any empty row that has no
  recorded reason. `isopleth_table()` and the `SpatRaster` method set the
  areas of the empty rows to `NA`, and warn once.
- The UDs are named in the warning by `hr_group_labels()`, as in the names
  of the UDs.
- The contour lines are matched to the levels by value, so that a level such
  as `1/3` is returned exactly.
- **Tests:**
  - `test_hr_tt_ud_iso.R`: rasters with a dominant cell, a uniform raster, a
    0% level, an all-`NA` UD, the cut of long warnings, exact levels, and a
    two-track table built with the exact KDE;
  - `test_hr_tt_mcp.R`, `test_hr_tt_locoh.R` and `test_hr_tt_dbbmm.R`.

## Open questions

- The issue's example no longer fails with the default binned KDE (#94
  spreads a location over four cells), only with `method = "exact"`. Binned
  UDs on coarse grids can still hit the rule.
