# tidytracks: progress

Log of major activity, newest first. Never rewrite old entries: add a
correction as a new entry.

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
