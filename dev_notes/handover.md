# tidytracks: handover

Updated 2026-11-19 (manica01). For the next session: read this and
`summary.md` first. History is in `progress.md`; designs are in the topic
documents listed in `README.md`.

## Branches

| branch | purpose | base | pushed | merged |
|---|---|---|---|---|
| `kde_units` | distances with units: `h`/`res` of the UD functions, LoCoH `n`/`buffer`, split-trip buffers, `uere`; decisions in `dev_notes/units.md` | `dev` (`6b3d855`; `dev` at `a433574` merged in) | yes | no (PR #103) |
| `interpolate_empty` | events without a location are flagged by `event_flag_mcconnell()` and `event_flag_outliers()` (#81) | `dev` | yes | no (PR #104) |
| `move2utilsbug` | two draft move2utils bug reports, now copied to `dev_notes/` | `main` | yes | no (no PR) |
| `fpt` | Lizzie: first passage time; reviewed in `codereview_fpt` | `dev` | yes | no |
| `codereview_fpt` | review of `fpt`: fixes, speed-up, new defaults, article; report in `dev_notes/code_review_fpt_2026-11.md` | `fpt` | yes | no (PR #101) |
| `get_data_ready_vignette` | Paul: vignette text (January 2026) | — | yes | no |
| `tt_and_move2_diffs` | Holly: wording (September 2026) | — | yes | no |

- **Merged into `dev`:** PRs #95–#100. Their branches are deleted on origin.
- **Squash-merged:**
  - `attribution` (#102, 19 Nov, `a433574`) is deleted on origin, and still
    local;
  - `inbound` (#91) is still on origin;
  - `kde_locoh_fast` (#94; its content is all in `dev`), `kde_fast`,
    `locoh`, `locoh_fast` and `benchmark-sizes` are local. Check each
    against `dev` before deleting it.

## Next tasks

The next steps of `summary.md`, in the same order and with the same labels.

### 1. **P1** [review] Review and merge PR #102 (done)

- Squash-merged into `dev` on 19 Nov (`a433574`). The local branch
  `attribution` is left to delete (task 6).

### 2. **P1** [andrea] Send Lizzie the note on the data

- **The note:** `dev_notes/note_for_Lizzie.md` (on `attribution` until #102
  is merged). It asks:
  - the owners, permissions, licences and citations of the shag data
    (`inst/extdata/shags_example.csv`, `data-raw/raw_csv/shag_*.csv`,
    `vignettes/articles/data/shags_*.csv`) and of the wandering albatross
    data (`vignettes/articles/data/wanderer_example_tracks.csv`);
  - whether to delete the two unused files in `inst/extdata/csv_files/`
    (done: removed, Nov 2026; the raw shag files too, archived outside the
    repo);
  - whether the raw albatross files in the git history must go (that would
    need a history rewrite).
- **Then (a Claude session):** record the answers (e.g. in
  `R/dataset_docs.R` or a note in `inst/extdata`, and in the vignettes), or
  replace or remove the data.
- **Done when:** each data set has a recorded source and licence, or is
  replaced.

### 3. **P3** [claude] Method citations and small credits

- The report, "Missing method citations" and "Small attribution items":
  - `hr_tt_kde()`, `hr_tt_ud_overlap()`, McConnell, the outlier functions,
    `tt_split_trips()`, the ctmm functions, the main vignette;
  - the Esri credit under the map and the animation of
    `vignettes/articles/animations.Rmd` ("Esri, Garmin, GEBCO, NOAA NGDC,
    and other contributors"; "Powered by Esri");
  - a note for the wild boar test data (`adehabitatMA::puechabonsp`,
    D. Maillard).

### 4. **P2** [review] Review and merge PR #103 (distances with units)

- **Read:** `dev_notes/units.md` (the decisions and the arguments checked),
  then the commits, one per function: `d26498f` (`hr_tt_kde()`,
  `hr_tt_akde()`, the output columns), `9bcc317` (ctmm article re-knitted),
  `67d2216` (`hr_tt_akde_pop()`), `a9d7970` (`hr_tt_locoh()`), `ee94b00`
  (`tt_split_trips()`), `5d1523e` (`ctmm_tt_fit()`), `cf8f6b2` (examples),
  `d1d4cd9` (`hr_benchmark.R`), `0a5e131` (word list).
- **Checks already done:** the full suite with move2utils (only the emdist
  test skipped); R CMD check on `0a5e131`: 0 errors, 0 warnings (the NOTEs
  and the WKT/multipolygon spelling words predate the branch). After #102
  was merged, `dev` (`a433574`) was merged into the branch: the code had no
  conflicts, and the three living notes were taken from this branch (they
  already contained `dev`'s). The full suite passes on the merged tree
  (`1dbd9b2`, with move2utils; only the emdist test skipped).
- **To know:** breaking changes, in NEWS: plain numbers give an error; the
  `hr_tt_locoh()` `buffer` default is `NULL`; code that compares the `h`,
  `res` or `n` columns with plain numbers needs `as.numeric()`. The
  deprecated `hr_kde()` still takes plain numbers.
- **Done when:** PR #103 is merged into `dev`; then delete `kde_units`.

### 5. **P2** [review] Review and merge PR #104 (events without a location, #81)

- **Read:** the PR description and its one commit (another session, 19 Nov).
- **Checks already done:** the issue's reprex; the changed test files
  (McConnell, outliers, move2utils bridge, geometry column name), with
  move2utils installed; the examples of the four functions; lintr. The new
  expectations fail on the old code. Not the full suite: CI runs it.
- **To know:** `flag_action = "remove"` (the default) now removes the
  events without a location (they were kept). No conflicts with PR #103
  (`git merge-tree`).
- **Done when:** PR #104 is merged into `dev` and closes #81; then delete
  `interpolate_empty`.

### 6. **P3** [cleanup] Delete merged branches

- Delete the local branch `attribution` (squash-merged by #102).
- Delete `inbound` on origin.
- Check, then delete, the local squash-merged branches (see "Branches").

### 7. **P1** [andrea] Send Lizzie the note on the FPT review

- The note is the Claude doc "FPT review: note to Lizzie" (private: share it
  first). It points her to the article
  (`vignettes/articles/first_passage_time.Rmd`) and to the report
  (`dev_notes/code_review_fpt_2026-11.md`), both on `codereview_fpt`.
- **Done when:** Lizzie has reviewed the branch and ticked the report's boxes,
  or listed what to change.

### 8. **P2** [review] Merge #101 (`codereview_fpt`) into `fpt`, then `fpt` into `dev`

- `codereview_fpt` is `fpt` plus the review: 28 commits, verified by separate
  agents. R CMD check was OK at `a27a29b` (1,694 tests, 0 lints).
- **Conflicts to expect:**
  - `.Rbuildignore` (`^dev_notes$` is in `dev` now);
  - the report must be added to `dev_notes/README.md`.
- The attribution audit found no copied code in `src/fpt.cpp` (an
  independent design on the definition of `adehabitatLT::fpt()`).
- **Done when:** `fpt` is merged into `dev`; then delete `codereview_fpt`
  and `fpt`.

### 9. **P2** [andrea] File the upstream reports

- Rerun the example in `move2_track_data_issue.md` with the latest move2, and
  update its output.
- File the move2 report (GitLab `bartk/move2`). Then file the two move2utils
  reports (MPCDF GitLab, mirrored at `move2universe/move2utils`), unless they
  are filed already.
- Then delete `move2utilsbug`.

### 10. **P2** [decide] Code review 2: open issues

- Read `codereview_2026-10.md`, and pick the items to fix. A fix is one
  branch from `dev` per item, with a test, and a NEWS bullet.

### 11. **P3** [claude] Check the review items that #95 may have fixed

- **Branch:** `dev` (#95 is merged).
- **Do:** try `event_ud_level()` with a one-row table of UDs and events of
  several tracks, and `hr_tt_ud_overlap()` on a table grouped by a factor.
  Mark the items as fixed in `codereview_2026-10.md`, or file issues.

### 12. **P3** [decide] Later ctmm analyses

- See `ctmm_integration.md`, "Later: further analyses built on the model
  table".

## Desktop queue

None.

## Backlog

- **Not installed on manica01:** emdist (1 test skipped); ask Andrea
  before installing it. move2utils 0.4.6 was installed on 19 Nov (with
  Andrea's approval).
- **MCP in C++:** parked by Andrea on 19 Nov. The design and the numbers
  are in `mcp_cpp.md` (about 10x faster on many tracks, but different
  vertices from `chull()` in nearly collinear sets).
- **Bugs found by the attribution verifier, also on `dev`:**
  - an s2 error of `hr_tt_locoh()` on rounded lon/lat;
  - `shadow_wake_build(wrap = )` has no effect;
  - `locoh_cpp()` reads out of bounds on empty input (not reachable from
    `hr_tt_locoh()`).
- **LoCoH speed-ups** (attribution report, "Speed-ups not done"):
  - do not store the neighbour sets of `"r"`, which are most of its memory
    now (32.6 GB for 1 M locations);
  - make the k-nearest-neighbour heap of `"a"` faster (about half of its
    time).
- **FPT review:** 5 minor findings (report, "Findings not fixed").
- **`hr_tt_ud_iso()` and the KDE isopleths:** a grouping variable named
  `level`, `area` or `geometry` clashes with the result columns (predates
  #92).
- **Next release:** check the deprecation version of `.keep = TRUE`
  ("0.3.0").
- **Documentation:** the documentation review (#90), and the data cleaning
  vignette (#65).
- **#81** (McConnell interpolation): PR #104 (task 5).
