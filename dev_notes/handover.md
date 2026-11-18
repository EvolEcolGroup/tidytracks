# tidytracks: handover

Updated 2026-11-18 (manica01). For the next session: read this and
`summary.md` first. History is in `progress.md`; designs are in the topic
documents listed in `README.md`.

## Branches

| branch | purpose | base | pushed | merged |
|---|---|---|---|---|
| `attribution` | audit of borrowed code and licences: rewrites, notices, credits; report in `dev_notes/code_review_attribution_2026-11.md` | `dev` (`6b3d855`) | no | no |
| `move2utilsbug` | two draft move2utils bug reports, now copied to `dev_notes/` | `main` | yes | no (no PR) |
| `fpt` | Lizzie: first passage time; reviewed in `codereview_fpt` | `dev` | yes | no |
| `codereview_fpt` | review of `fpt`: fixes, speed-up, new defaults, article; report in `dev_notes/code_review_fpt_2026-11.md` | `fpt` | yes | no (PR #101) |
| `get_data_ready_vignette` | Paul: vignette text (January 2026) | — | yes | no |
| `tt_and_move2_diffs` | Holly: wording (September 2026) | — | yes | no |

- **Merged into `dev`:** PRs #95–#100. Their branches are deleted on origin.
- **Squash-merged:**
  - `inbound` (#91) is still on origin;
  - `kde_locoh_fast` (#94; its content is all in `dev`), `kde_fast`,
    `locoh`, `locoh_fast` and `benchmark-sizes` are local. Check each
    against `dev` before deleting it.

## Next tasks

The next steps of `summary.md`, in the same order and with the same labels.

### 1. **P1** [review] Review `attribution`, then push it and open a PR into `dev`

- **Read:** `dev_notes/code_review_attribution_2026-11.md`, "Fixes by area":
  one entry per commit, `8b2960b`..`23780f7`.
- **Checks already done:**
  - identical results to `dev` for MCP and LoCoH;
  - R CMD check: 0 errors, 0 warnings (NOTEs: move2utils is not installed
    on manica01, and "WKT" and "multipolygon" in the spelling test come
    from `dev`);
  - the full suite on the tip;
  - an independent agent verified every commit (sanitizer build of the hull
    code included).
- **To know:** `a78fb56` left `man/tidytracks-package.Rd` stale; `99e0d68`
  regenerates it.
- **Done when:** the PR is merged into `dev`.

### 2. **P1** [collab] Data: owners, permissions and licences

- **Shag tracks:**
  - where: `inst/extdata/shags_example.csv` (in the package; main vignette,
    examples of `tt_read_data()`), `data-raw/raw_csv/shag_*.csv` (which
    look like the raw data) and `vignettes/articles/data/shags_*.csv`;
  - to record: owner, permission, licence, citation (e.g. in
    `R/dataset_docs.R` or a note in `inst/extdata`, and in the vignette).
- **Wandering albatross tracks** (`vignettes/articles/data/wanderer_example_tracks.csv`,
  animations article): probably from the Seabird Tracking Database.
  Permission and citation, or other data.
- **Unused files:** remove `inst/extdata/csv_files/dataset_example_birdlife.csv`
  (Seabird Tracking Database dataset 1387) and
  `shag_tidytrack_sample_subset_old.csv`.
- **Credits to add:**
  - the Esri basemap in `vignettes/articles/animations.Rmd:313` needs a
    caption ("Esri, Garmin, GEBCO, NOAA NGDC, and other contributors";
    "Powered by Esri");
  - a note for the wild boar test data (`adehabitatMA::puechabonsp`,
    D. Maillard).
- **Done when:** each data set has a recorded source and licence, or is
  replaced.

### 3. **P2** [decide] s2 error of `hr_tt_mcp()` on some lon/lat data

- **The problem:** `grDevices::chull()` can return two vertices that s2
  treats as the same point. s2 then rejects the ring ("Edge 9 is degenerate
  (duplicate vertex)"). The verifier's example: lon/lat rounded to 3
  decimals, level 0.9.
- **The fix:** drop repeated vertices in `mcp_polygon()` (`R/hr_tt_mcp.R`),
  with a test. Outputs change only where they fail now.
- **Related:** `hr_tt_locoh()` has a similar s2 error on rounded lon/lat
  (report, "Bugs found by the verifier").

### 4. **P3** [decide] MCP in C++

- **The gain:** most of the time of `hr_tt_mcp()` on many short tracks is the
  R overhead of `grDevices::chull()`. A C++ version (with the monotone chain
  of `src/locoh.cpp`, the vertices ordered as `chull()` does) would be about
  10x faster per group.
- **The cost:** `chull()` decides nearly collinear points differently. There
  were no differences in 2,535 real hulls, but 607 in 20,000 degenerate
  sets.

### 5. **P3** [claude] Method citations and small credits

- The report, "Missing method citations" and "Small attribution items":
  - `hr_tt_kde()`, `hr_tt_ud_overlap()`, McConnell, the outlier functions,
    `tt_split_trips()`, the ctmm functions, the main vignette;
  - optional `cph` roles for W. R. Franklin, P. Ramsey and M. Davis.

### 6. **P3** [cleanup] Close #82 and delete merged branches

- Close #82 (fixed by #100).
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

- **Not installed on manica01:** move2utils (70 tests skipped) and emdist.
  Ask Andrea before installing them, for complete checks.
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
- **Open issue:** #81 (McConnell interpolation).
