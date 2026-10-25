# Plan: integrating ctmm into tidytracks

Status: draft for review. Nothing has been implemented yet.

## Goals

1. Fit continuous-time movement models from **ctmm** directly on a tidytracks
   `move2` object. The output is a **table of models with one row per track, in
   the same order as `show_meta(x)`**, so it can be joined or bound to the
   metadata and used for further analyses.
2. Keep fitting separate from estimation. Every ctmm-based estimator, starting
   with AKDE, takes the **original `move2` object and the model table as
   required inputs**. It never fits a model silently.
3. AKDE output should be a standard `hr_tt_ud_tbl`, so `hr_tt_ud_iso()`,
   `hr_tt_ud_overlap()`, `hr_tt_ud_sum()`, `autoplot()` and the wrap/save
   helpers work unchanged. The ctmm `UD` objects are kept alongside so their
   confidence intervals are not lost.
4. ctmm stays in `Suggests`. Use `rlang::check_installed("ctmm")` at the start
   of each ctmm-dependent function.

## What the existing packages do

### move2 (0.5.1)

* `mt_as_move2.telemetry()` and `mt_as_move2.list()` convert ctmm `telemetry`
  objects to `move2`. **ctmm to move2 is already covered.**
* There is no move2 to `telemetry` converter. The only route is
  `move2::to_move()` (old move/raster/sp classes), then
  `ctmm::as.telemetry.Move()`.

### ctmm (1.3.1)

* `as.telemetry()` methods exist for `character`, `data.frame`, `Move` and
  `MoveStack`. An `sf` method exists, but it is unfinished, unexported and
  named `UNFINISHED.as.telemetry.sf`.
* `as.telemetry.data.frame()` identifies columns by *canonicalised* name:
  separators are removed and names are lowercased. So Movebank-style names work
  with dots or underscores (`individual_local_identifier`, `gps_hdop`,
  `eobs_horizontal_accuracy_estimate`, `argos_lc`, ...). It drops
  tibble/grouped classes itself.
* `projection =` accepts an `sf` `crs` object, which ctmm converts to a PROJ4
  string. ctmm refuses long/lat CRSs and non-metre units
  (`validate.projection()`).
* Model fitting:
  * `ctmm.guess(data, CTMM = ctmm(error = ...), interactive = FALSE)` gives the
    starting values.
  * `ctmm.select(data, guess, IC = "AICc", cores = ...)` gives the best model.
    With `verbose = TRUE` it returns the ranked list of candidate models.
  * `ctmm.fit(data, ctmm(...))` fits one given model.
* `akde(data, CTMM, debias, weights, error, res, grid)`:
  * `data` and `CTMM` can be lists. Several individuals are forced onto
    compatible grids.
  * `grid` can be fully specified as `list(r = list(x = <cell centres>,
    y = <cell centres>))` (see `kde.grid()` in `R/grid.R`). **This lets ctmm
    estimate directly on our grid, with no resampling.**
  * If the model's area DOF is too small, it returns the *model* rather than a
    UD, with a warning.
  * It requires data and models to be in the same projection.
* `UD` objects hold `PDF`, `CDF`, `r$x`, `r$y` and `dr`; `PDF * prod(dr)` is
  the probability mass per cell. `ctmm::raster(UD)` returns a `raster::` object,
  which we would rather build ourselves with terra.
* Summaries:
  * `summary(ctmm_fit, units = FALSE)` gives parameter CIs (area, tau position,
    tau velocity, speed, diffusion) and DOF.
  * `summary(UD, level.UD, level, units = FALSE)` gives home-range area with
    CIs.
* Downstream functions that could build on the model table: `occurrence()`,
  `overlap()` (bias-corrected Bhattacharyya with CIs), `meta()` (population
  meta-analysis), `mean.ctmm()`, `pkde()`, `speed()`/`speeds()`, `predict()`,
  `simulate()`, `outlie()`, `uere()`/`uere.fit()`, `encounter()`,
  `distances()` and `rsf.fit()`.

### amt (0.3.1)

amt is the closest precedent.

* `as_telemetry.track_xyt()` builds a minimal data frame (lon, lat,
  timestamp, `individual.local.identifier = 1`, plus `dop`/`hdop` if present)
  and calls `ctmm::as.telemetry()`. It handles a single track only and always
  lets ctmm choose the projection.
* `fit_ctmm(x, model = c("iid", "bm", "ou", "ouf", "auto"), uere = NULL)`:
  * uses `ctmm.guess()` to seed the fit;
  * uses `ctmm.fit()` with a given tau structure, or `ctmm.select()` for
    `"auto"`;
  * sets `uere(dat) <- uere` when location error is requested.
* `hr_akde(x, model = fit_ctmm(x, "iid"), trast = make_trast(x), levels)`:
  * fits a model by default, *inside* the estimator;
  * runs `ctmm::akde()`, then `terra::project()` + `terra::resample()` onto
    amt's template raster;
  * returns a list holding `ud` (raster), `akde` (the ctmm `UD`) and `model`.
* `hr_isopleths.akde()` uses `ctmm::SpatialPolygonsDataFrame.UD()` to return
  three polygons per level (`lci`, `estimate`, `uci`) with a `what` column.
  `hr_area.akde()` reports the CI on area.

**Ideas worth borrowing from amt:**

* keyword shortcuts for common model structures;
* keeping the ctmm `UD` next to the raster, so CIs remain available;
* reporting confidence intervals on isopleths and areas;
* picking up DOP/error columns automatically.

**What we should do differently:**

* Fit once, as a separate step. amt's default `model = fit_ctmm(x, "iid")`
  hides an expensive step, and an IID model reduces AKDE to a plain KDE.
* Handle many tracks at once, aligned with the metadata.
* Estimate directly on our grid instead of re-projecting and resampling, which
  is lossy and moves probability mass.
* Don't wrap everything in `suppressWarnings(suppressMessages())`. ctmm's
  warnings, for example about low DOF or duplicate times, are informative.

## Proposed API

Names are provisional (see the open questions at the end).

### 1. `tt_as_telemetry(x, error_cols = "auto")`

Converts a `move2` object to a named list of `telemetry` objects, one per track
and in metadata order (`drop = FALSE`, so it is always a list).

* **Input checks:**
  * `x` must be a `move2` object with a projected CRS in metres. ctmm refuses
    anything else, and we need ctmm's coordinates to be identical to ours.
  * Error on long/lat, suggesting `sf::st_transform()` (e.g. with
    `move2::mt_aeqd_crs()`).
  * Time must be `POSIXct`.
  * Events with empty geometry are dropped.
* **Columns passed to ctmm:**
  * `individual.local.identifier` = track id;
  * `timestamp` = `mt_time(x)`;
  * `location.long`/`location.lat` from `st_transform(x, 4326)`;
  * `projection = sf::st_crs(x)`.
* **Coordinate check:** after conversion, compare ctmm's `x`/`y` with
  `st_coordinates(x)`. The PROJ4 round trip can drop datum details.
  * If the difference is negligible (e.g. below 1e-6 m), overwrite with ours so
    the grids match exactly.
  * Otherwise, error.
* **Location error:**
  * `error_cols = "auto"` passes through a whitelist of known Movebank error
    columns found in the event data: HDOP/DOP, `eobs_horizontal_accuracy_*`,
    `gps_horizontal_accuracy_*`, Argos ellipse/LC, and the marked-outlier
    flags.
  * `error_cols` can also be an explicit character vector, or `NULL` for none.
  * We **never pass the whole event table**. Otherwise columns such as
    `tag_local_identifier`, `x`, `y` or `height` could be picked up by ctmm as
    the id, coordinates or altitude through its name matching.
* Exported, so users can go to ctmm directly. The reverse direction is already
  `move2::mt_as_move2()`.

### 2. `tt_fit_ctmm(x, model = "auto", error = FALSE, uere = NULL, IC = "AICc", keep_candidates = FALSE, cores = 1, ...)`

Fits one movement model per track and returns a **`tt_ctmm_tbl`**: a tibble
with **one row per row of `show_meta(x)`, in the same order**.

* **`model`:**
  * A keyword: `"auto"` (`ctmm.select()` from `ctmm.guess()`), or `"iid"`,
    `"ou"`, `"ouf"`, `"bm"` (`ctmm.fit()` with the corresponding tau
    structure, as in amt).
  * Or a `ctmm()` template object, used for all tracks.
  * Or a list of templates, one per track.
* **`error`/`uere`:** passed to `ctmm(error = ...)`. Setting `uere` sets
  `uere(tel) <- uere` first.
* **`...`:** forwarded to `ctmm.select()`/`ctmm.fit()`.
* **Iterating over tracks:** with `foreach %do%`, consistent with
  `hr_tt_kde()`, leaving room for `%dopar%` later.
* **Failures don't break the alignment.** Each fit is wrapped in `tryCatch()`.
  A track that cannot be fitted (too few locations, non-convergence) gets
  `model = list(NULL)` and the error message in `fit_message`.
* **Columns:**
  * `<track id column>`, named as in `x`;
  * `model`: list-column of `ctmm` objects;
  * `model_name`: e.g. `"OUF anisotropic"`, from `summary(fit)$name`;
  * `n_events`, `t_start`, `t_end`: a fingerprint of the data used for the fit.
    Estimators check it against `x` and error if the track has changed since
    fitting (e.g. after further filtering);
  * `ic`: the AICc (or chosen IC) of the selected model;
  * `dof_area`: effective sample size for area. Useful for spotting tracks
    unsuitable for AKDE;
  * `fit_message`: `NA`, or the error/warning text;
  * `candidates` (only if `keep_candidates = TRUE`): the ranked candidate list
    from `ctmm.select(verbose = TRUE)`, for model-selection tables.
* The table stores its CRS as an attribute.
* Methods: `print`, and `[`/dplyr methods that keep the class, as for
  `hr_tt_ud_tbl`.
* Because the order matches the metadata, `show_meta(x)$ctmm <- fits$model`
  works if users want the models to travel with the object. We document this
  but don't do it by default (see open question 2).
* **Grouping:** models are fitted per *track*. Analyses at other levels (trips,
  seasons) should first make those the tracks, e.g. with `tt_split_trips()` or
  `move2::mt_set_track_id()`, and then refit. Grouped input to `tt_fit_ctmm()`
  is an error that explains this.

### 3. `tt_ctmm_summary(models, level = 0.95)`

Turns `summary.ctmm(units = FALSE)` into a long, tidy table: track id,
`parameter` (area, tau_position, tau_velocity, speed, diffusion), `low`, `est`,
`high`, as `units` objects. It is joinable to the metadata for downstream
modelling (e.g. area ~ sex).

### 4. `hr_tt_akde(x, models, bbox = NULL, res = NULL, levels = NULL, debias = TRUE, weights = FALSE, error = 0.001, ci_level = 0.95, keep_ctmm = TRUE)`

Both `x` and `models` are **required**; there is no default model.

1. **Checks:**
   * `models` is a `tt_ctmm_tbl` with the same CRS as `x`.
   * Every track/group in `x` has a non-NULL model, matched **by id**, so a
     subset of `x` with the full model table works.
   * The fingerprint matches.
   * The model is range-resident. BM/IOU have no home range, so error, as amt
     warns.
2. **Groups:** as in `hr_tt_kde()`, ungrouped means one UD per track.
   * v1: a group may contain only one track.
   * Grouping by a metadata variable that pools several tracks comes in
     phase 4 (`pkde()`/`mean.UD`).
   * Grouping by an event-level variable that splits tracks is an error (see
     the grouping note above).
3. **Shared grid** (needed for overlap and sum):
   * Reuse `normalise_kde_bbox()`, `align_kde_bbox()` and `kde_resolution()`.
   * The default `bbox` is the union of the data extent and
     `ctmm::extent(models, level = 1 - error)`, so the UD is not truncated.
   * Passed to ctmm as
     `grid = list(r = list(x = <cell centres>, y = <cell centres>))`.
   * Per-group `bbox`/`res` work as in `hr_tt_kde()`.
4. **Estimation:** call `ctmm::akde(tel, fit, grid = ..., debias, weights,
   error)` per group. `weights = TRUE` (optimal weighting for irregular
   sampling and gaps) is a key feature for tracking data and should be
   documented prominently.
5. **Conversion to raster:**
   * Build the `SpatRaster` from `UD$PDF * prod(UD$dr)` directly with
     `terra::rast()`, flipping rows the same way as `kde_one_group()`.
   * Assert that the extent equals our bbox exactly.
   * Normalise to sum to 1 and name the layer `"ud"`.
   * Metatags: `method = akde`, model name, `density_sum`.
   * Warn if `density_sum < 1 - 10 * error`, i.e. the grid truncates the UD.
6. **Output:** an `hr_tt_ud_tbl` with:
   * the id column, `method = "akde"`, `model` (name), `dof_area`, the bbox
     columns, `res`, and `ud`;
   * `ud_ctmm`, a list-column of ctmm `UD` objects, if `keep_ctmm`;
   * no `h` column. Nothing downstream uses it; I checked iso, overlap, sum and
     autoplot.
7. **`levels`:**
   * Polygons and `area` come from `hr_tt_ud_iso()`, consistent with the other
     methods.
   * Add `area_low`/`area_high` from `summary(UD, level.UD = level,
     level = ci_level, units = FALSE)` when `ud_ctmm` is available.
   * CI polygons (amt's `lci`/`estimate`/`uci` with a `what` column, via
     `ctmm::as.sf()`) come in phase 3.

Small change needed elsewhere: `hr_tt_ud_iso.tbl_df()` must also drop
`ud_ctmm` (`select(-any_of(c("ud", "ud_ctmm")))`). Overlap, sum, autoplot and
wrap/save only touch `ud`. Check that `hr_tt_ud_sum()` drops non-summable
list-columns.

### 5. Later: further analyses built on the model table

Each of these takes `(x, models)` or `models` alone:

* `hr_tt_occurrence(x, models)`: `ctmm::occurrence()` on our grid, returning an
  `hr_tt_ud_tbl` with `method = "occurrence"`.
* `hr_tt_ud_overlap(..., method = "ctmm")`: `ctmm::overlap()` on `ud_ctmm`,
  giving bias-corrected Bhattacharyya overlap with CIs.
* Population-level analyses:
  * `ctmm::meta()` on areas/UDs by a metadata variable;
  * `mean.ctmm()` for a population model;
  * `pkde()` for grouped `hr_tt_akde()`.
* `track_ctmm_speed(x, models)`: `ctmm::speed()` with CIs, one row per track.
* Simulations and predictions: `ctmm::simulate()`/`predict()` conditioned on
  the data, returned as `move2` via `mt_as_move2()`, e.g. for imputing gaps.
* `event_flag_ctmm_outlier(x)`: `ctmm::outlie()` (needs no model).

## Implementation phases

| Phase | Content | Tests |
|---|---|---|
| 1 | `tt_as_telemetry()`, `tt_fit_ctmm()`, `tt_ctmm_tbl` class/print, `tt_ctmm_summary()` | Row order equals `show_meta()` order; ids and coordinates round-trip (`mt_as_move2()`); long/lat input errors; a failing track gives a NULL row with a message and doesn't break the alignment; keyword models give the expected `model_name`; error columns are whitelisted |
| 2 | `hr_tt_akde()` (one track per group, shared grid, `ud_ctmm`), `hr_tt_ud_iso` tweak | UD sums to 1; grid identical to the requested bbox/res; works with iso/overlap/sum/autoplot/saveRDS; errors for missing, mismatched or BM models; isopleth area close to `summary(UD)` estimate |
| 3 | Area CIs and CI polygons with `levels`; vignette article "Movement models with ctmm" | CI ordering low ≤ est ≤ high |
| 4 | Pooled groups (`pkde`), `hr_tt_occurrence()`, ctmm overlap, speed, etc. | — |

* **Test cost:** ctmm fitting is slow. Use small subsets of `example_tt` and
  explicit `"ou"`/`"iid"` models, with `"auto"` only in a single test.
  Everything is guarded by `skip_if_not_installed("ctmm")`.
* **DESCRIPTION:** add `ctmm` to `Suggests` (it brings raster/sp, but only for
  users who install it).

## Open questions for review

1. **Names.** I propose `tt_as_telemetry()`, `tt_fit_ctmm()` with the
   `tt_ctmm_tbl` class, `tt_ctmm_summary()` and `hr_tt_akde()`. Alternatives:
   `hr_tt_ctmm_fit()`, or `track_ctmm_fit()`, since the result has one row per
   track.
2. **Where the models live.** A standalone, metadata-aligned table
   (recommended: explicit, easy to subset or save, and it doesn't put S4
   objects inside the `move2` metadata), or a list-column added directly to
   `show_meta(x)`?
3. **Default `model`.**
   * `"auto"` (recommended): slow but statistically sound.
   * No default, forcing an explicit choice.
   * Not amt's `"iid"`, which reduces AKDE to a plain KDE.
4. **Long/lat input.**
   * Error and ask the user to project (recommended): the UDs are then in the
     user's CRS, which matches `x`.
   * Or project internally (e.g. `mt_aeqd_crs()`) and return UDs in that CRS.
5. **Default `res` for AKDE.**
   * Our "about 1000 cells" rule can be coarse relative to the AKDE bandwidth
     when animals range far apart.
   * Alternative: a ctmm-like default derived from the models (smallest model
     SD / 10), with a cap on the total number of cells and a warning.
6. **Location error.** Is auto-detecting Movebank error columns (on by default)
   desirable, or should it be opt-in?
7. **Pooled groups** (e.g. one UD per colony from several tracks):
   population KDE (`pkde`, correct but slow), a weighted `mean()` of the
   individual UDs, or out of scope?
