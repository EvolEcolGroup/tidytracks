# tidytracks: progress

Log of major activity, newest first. Never rewrite old entries: add a
correction as a new entry.

## 2026-11-19 (manica01): distances with units (PR #103)

- **Done:** `h` and `res` of `hr_tt_kde()`, `res` of `hr_tt_akde()`, `n`
  (types `"r"`, `"a"`) and `buffer` of `hr_tt_locoh()`, the buffers of
  `tt_split_trips()` and `uere` of `ctmm_tt_fit()` must be `units` objects;
  the `h`, `res` and `n` columns have units. Re-knitted the ctmm article.
- **Where:** branch `kde_units` (from `dev`), `d26498f`..`0a5e131`; PR #103.
- **Result:** full suite passes with move2utils (now installed on manica01,
  0.4.6); R CMD check 0 errors, 0 warnings. No conflicts with PR #102.
- **Decisions** (Andrea): `h` has units (the maths); enforce units in every
  function, with no backward compatibility for `hr_tt_akde_pop()` tables.
- **Notes changed:** `units.md` (new), `codereview_2026-10.md` (3 items
  fixed), `README.md`, `summary.md`, `handover.md`.

## 2026-11-19 (manica01): PR #102, an MCP fix, and the data note

- **Done:**
  - fixed the s2 error of `hr_tt_mcp()` with duplicated lon/lat locations:
    `grDevices::chull()` can return a location and its duplicate as two
    vertices, and 15 of 400 rounded tracks failed;
  - wrote up the parked C++ MCP (`mcp_cpp.md`) and the questions on the
    data for Lizzie (`note_for_Lizzie.md`);
  - opened PR #102.
- **Where:** branch `attribution`, `ae5ffa6` (fix), `7ae85bb` (notes); PR
  #102 into `dev`.
- **Result:** of 21,147 polygons, the 62 that changed are the hulls with a
  repeated vertex; +0.8% instructions on 10,000 tracks.
- **Decisions** (Andrea): open the PR; do the fix; park the C++ MCP; no `cph`
  roles; the data questions go to Lizzie.
- **Notes changed:** `mcp_cpp.md` and `note_for_Lizzie.md` (new), the report,
  `README.md`, `summary.md`, `handover.md`.

## 2026-11-18 (manica01): code attribution and licence audit

- **Done:** audited the package and the repository for borrowed code and
  licence problems (scan against 18 upstream packages, three comparing
  agents, history), then fixed what Andrea approved. Rewrote `dist_fast()`
  (from trip, GPL-3 only), the MCP helpers (from amt, GPL-3 only) and the
  LoCoH convex hulls (from Wikibooks, CC BY-SA). Added notices and credits:
  gganimate (MIT), PNPOLY, GEOS/JTS, and the move2 authors. Removed
  `dev_notes/explorations/temp/`. An independent agent verified every commit.
- **Where:** branch `attribution` (local), `8b2960b`..`23780f7`; report
  `dev_notes/code_review_attribution_2026-11.md`.
- **Result:** identical results. MCP is 15% faster on many tracks; LoCoH
  needs up to 8x less memory (`"r"` on 1 M locations now runs, in 32.6 GB;
  `dev` was killed above 94 GB). R CMD check: 0 errors and 0 warnings.
- **Decisions** (Andrea): rewrite the GPL-3 and CC BY-SA code with credit to
  the methods; add `inst/COPYRIGHTS` and `ctb` credits; remove `temp/`; the
  data later.
- **Notes changed:** `code_review_attribution_2026-11.md` (new),
  `README.md`, `summary.md`, `handover.md`.

## 2026-11-16 (laptopX1): PR #101 for the FPT review

- **Done:** opened PR #101, `codereview_fpt` into `fpt`; deleted the local
  `codereview_fpt_speedup` (merged into `codereview_fpt`).
- **Notes changed:** `summary.md`, `handover.md`, `progress.md`.

## 2026-11-16 (laptopX1): review of the first passage time functions (`fpt`)

- **Done:** reviewed Lizzie's `fea842f` on 12 real datasets; the FPTs equal
  `adehabitatLT::fpt()` exactly. Fixed 5 bugs, sped up the C++ search (9× on
  72k fixes, about linear in track length), set three new defaults, rewrote
  the examples, and added the article "Area-restricted search with first
  passage time". Three verifying agents checked every commit; the second and
  third found two bugs introduced by the review, both fixed.
- **Where:** branch `codereview_fpt` (pushed, no PR); report
  `dev_notes/code_review_fpt_2026-11.md` there. R CMD check OK (1,694 tests).
- **Decisions** (Andrea): merge the speed-up; default radii per track or
  group; a radius needs half of the locations (`min_prop_valid = 0.5`, rather
  than 30 events); the highest peak as default method.
- **Notes changed:** `summary.md`, `handover.md`, `progress.md`, `README.md`.

## 2026-11-16 (laptopX1): wrap-up, Andrea's last decisions

- **Done:** recorded Andrea's last decisions, and wrote the design note
  `isopleths.md` (#82). CI passes all 9 jobs on all six PRs (#95–#100). All
  the home range test files pass locally on `iso_empty_levels`.
- **Where:** branch `dev_notes` (PR #99).
- **Decisions** (Andrea):
  - no `select_by_meta()`;
  - the table of UDs of `hr_tt_dbbmm()` still leaves out tracks too short
    for `window_size`;
  - MCP and LoCoH groups with too few locations still give an error.
- **Notes changed:** `summary.md`, `handover.md`, `metadata_and_events.md`,
  `isopleths.md` (new), `README.md`.

## 2026-11-16 (laptopX1): isopleths that cannot be drawn (#82)

- **Done:** every isopleth that cannot be drawn is kept as a row, with an
  empty geometry, an `NA` area, and a warning that gives the reason and a
  remedy. This covers the KDE-based isopleths, MCP and LoCoH home ranges with
  no area, and `hr_tt_dbbmm()` tracks too short for `window_size`. Levels
  such as `1/3` are no longer rounded.
- **Where:** branch `iso_empty_levels`, 7c171d6, PR #100, stacked on #98.
- **Result:** the new tests fail on the old code. The test files of
  `hr_tt_ud_iso`, `hr_tt_mcp`, `hr_tt_locoh` and `hr_tt_dbbmm` pass; the
  rest is left to CI. The issue's example no longer fails with the default
  binned KDE (#94), only with `method = "exact"`.
- **Decisions:** the rule itself (Andrea). Area `NA` rather than 0 for empty
  MCP and LoCoH polygons (Claude, applying the rule). The table of UDs of
  `hr_tt_dbbmm()` still leaves out short tracks: a question for Andrea.
- **Notes changed:** `summary.md`, `handover.md`.

## 2026-11-16 (laptopX1): Andrea's decisions on #92, and dev_notes/

- **Done:**
  - #96: the package code now calls `colname_track_id()` and
    `colname_time()` (32 calls in `R/`, 16 in the tests).
  - #97: `show_meta<-` runs the duplicate check; a grouping column stays in
    the events; `.keep = TRUE` is soft-deprecated, and `lifecycle` is added
    to Imports.
  - #98: `meta_columns` restricts the metadata columns that the geoms add.
  - Set up `dev_notes/`: the notes and explorations moved out of `data-raw/`,
    the two move2utils drafts were copied from `move2utilsbug`, and the move2
    issue was drafted.
- **Where:**
  - `colname_functions` 9d68108;
  - `no_duplicated_columns` 0ceed7d (merge), c65b270, df65a5d;
  - `geom_meta_columns` 779473d (merge), f6edee3;
  - branch `dev_notes`, PR #99.
  - The stacked branches merge the earlier ones, as force pushes were
    blocked.
- **Result:** the test files of every changed function pass locally. Only
  single test files were run, as tidygenclust timed jobs overnight; the full
  checks are left to CI.
- **Decisions** (Andrea): use the new names everywhere; check in the setter;
  keep `.meta` with a warning; soft-deprecate `.keep = TRUE`; add a
  `meta_columns` argument to the geoms; set up `dev_notes/`. Claude chose
  "0.3.0" as the deprecation version and `character(0)` for "none", since
  `c()` is `NULL` in R.
- **Gotcha:** lintr's `object_usage_linter` resolves functions in the
  *installed* tidytracks. Run `pkgload::load_all()` before
  `lintr::lint_package()`, or new internal functions show up as false lints.
- **Notes changed:** all of `dev_notes/` (new).

## 2026-11-15 (laptopX1): #92 items 1–4 in four stacked PRs

- **Done:**
  - `group_by_meta()`, which moves the grouping columns to the events;
  - typed group keys in the `hr_tt_*()` results, with no `group_id`;
  - `sf` tests of `filter_by_meta()`;
  - `colname_*()`;
  - one column per table in `tt_read_data()`, `tt_split_trips()` and the
    column movers;
  - metadata columns in the geoms.
- **Where:** PRs #95, #96, #97 and #98 into `dev`, stacked; merge them in
  that order.
- **Result:** local `R CMD check` of #95: 0 errors, 0 warnings, 0 notes. CI
  passed on all four PRs.
- **Decisions** (Andrea): scope (item 3 first, then the others); move the
  columns rather than copy them; keys only in the `hr_tt_*()` results, fixed
  in the same PR; merge in PR order.
- **Notes changed:** none; this entry was written on 16 Nov from the session.

## Before 2026-11-15: merged work, from git history

- #94 (13 Nov): faster binned KDE and LoCoH.
- #93 (11 Nov): CI cancels superseded runs, plus a check without suggested
  packages.
- #91 (10 Nov): `tt_split_trips()` buffers.
- #89, #87 (28–30 Oct): benchmarks.
- #88, #86 (28–29 Oct): code review 2, its fixes and the move2utils
  wrappers. Its open issues are in `codereview_2026-10.md`.
- #84 (27 Oct): ctmm, see `ctmm_integration.md`.
- #85 (27 Oct): new track functions.
- #79 (21 Oct): release 0.2.1.
