# tidytracks: summary

Updated 2026-11-16 (laptopX1). tidytracks has no jobs in
dramanica/claude_jobs: its work is tracked in its own GitHub issues, so the
sections below are by line of work, not by job.

## #92: metadata and events (PRs #95–#98)

The four items of #92: the only column in both the events and the metadata
is the track id.

**Status.** Four stacked PRs into `dev` are open: #95 (item 3), #96 (item 1),
#97 (item 2) and #98 (item 4). Merge them in that order. All CI jobs pass on
all four. Next tasks are in `dev_notes/handover.md`.

The PRs add:
- `group_by_meta()`;
- typed group keys in the `hr_tt_*()` results: one column per grouping
  variable, and no `group_id`, which changes existing results;
- `colname_track_id()` and `colname_time()`, now used across the package;
- the duplicate check in `tt_read_data()`, `tt_split_trips()`, the column
  movers and `show_meta<-`;
- the soft deprecation of `.keep = TRUE`;
- metadata columns in the `geom_event_*()` layers, with a `meta_columns`
  argument.

Andrea's decisions of 15–16 Nov are recorded in
`dev_notes/metadata_and_events.md`. There will be no `select_by_meta()`
(Andrea, 16 Nov).

**Next steps**
- [ ] **P1** [review] Review and merge #95, #96, #97 and #98, in this order: each branch merges the previous ones.
- [ ] **P3** [cleanup] Delete the branches of #95–#98 and #100 once merged, and the merged `benchmark-sizes` and `inbound`.

## #82: isopleths that cannot be drawn (PR #100)

Each UD, or group, always has one row per level. An isopleth that cannot be
drawn gets an empty geometry, an `NA` area, and a warning that gives the
reason and a remedy.

**Status.** PR #100 (branch `iso_empty_levels`) is stacked on #98, as #95 also
changes `hr_tt_ud_iso()`. It covers:
- the KDE-based isopleths (`hr_tt_ud_iso()`, and `levels` in `hr_tt_kde()`,
  `hr_tt_dbbmm()` and `hr_tt_akde()`);
- MCP and LoCoH home ranges with no area;
- `hr_tt_dbbmm()` tracks that are too short for `window_size`.

All CI jobs pass. Andrea decided on 16 Nov that the table of UDs of
`hr_tt_dbbmm()` still leaves out the tracks too short for `window_size`,
and that MCP and LoCoH groups with fewer than three locations still give an
error. The rule and its reasons are in `dev_notes/isopleths.md`.

**Next steps**
- [ ] **P1** [review] Review and merge #100 after #98.

## First passage time: review of `fpt` (branch `codereview_fpt`)

Lizzie's first passage time functions (`event_fpt()`, `track_fpt_profile()`,
`track_suggest_ars_scale()`; branch `fpt`), reviewed on 12 real datasets.

**Status.** Branch `codereview_fpt` (from `fpt`, pushed 16 Nov, no PR) holds
the review's fixes, an exact C++ speed-up (9× faster on a 72k-fix track,
about linear in track length), three new defaults decided by Andrea (radii per
track, at least half of the locations per radius, the highest peak), new
examples and the article "Area-restricted search with first passage time".
The FPTs equal `adehabitatLT::fpt()` exactly; R CMD check is OK (1,694
tests). Report: `dev_notes/code_review_fpt_2026-11.md` on that branch.

**Next steps**
- [ ] **P1** [andrea] Send Lizzie the note (Claude doc "FPT review: note to Lizzie", private until shared), so that she reviews `codereview_fpt`: the article, then the report's list of commits.
- [ ] **P2** [review] Merge `codereview_fpt` into `fpt`, then open a PR of `fpt` into `dev`: expect a small conflict with #99 in `.Rbuildignore`, and add the report to `dev_notes/README.md`.
- [ ] **P3** [cleanup] Delete the local branch `codereview_fpt_speedup` (merged into `codereview_fpt`), and `codereview_fpt` once merged.

## Developer notes

**Status.** `dev_notes/` was set up on 16 Nov in PR #99 (branch `dev_notes`,
from `dev`), with the notes and explorations moved out of `data-raw/`. It can
be merged at any time, independently of #95–#98.

**Next steps**
- [ ] **P2** [review] Review and merge #99.

## Upstream bug reports

Drafts of reports for move2 and move2utils, ready to paste into their issue
trackers.

**Status.** There are three drafts in `dev_notes/`:
- `move2_track_data_issue.md`: `group_by_track_data()` and
  `filter_track_data()` fail with `sf` track data, or with columns in both
  tables (from #92);
- `move2utils_bridge_kernels_issue/`: an out-of-bounds write in the Brownian
  bridge kernels, with a patch;
- `move2utils_clean_track_thresholds_issue.md`: `mt_clean_track()` ignores
  three thresholds with several tracks.

The two move2utils drafts were copied from the unmerged branch
`move2utilsbug` (October 2026). It is not recorded whether they were filed.

**Next steps**
- [ ] **P2** [andrea] File the three upstream reports, or confirm that they are filed; rerun the move2 example with the latest move2 first. Then delete the branch `move2utilsbug`.

## Code review 2: open issues

Issues from the review of October 2026 (#86) that need a decision before a
fix.

**Status.** About 40 open items, by area, in `dev_notes/codereview_2026-10.md`.
Two related problems were filed as GitHub issues: #81 (open) and #82 (fixed
by #100). #95 may have fixed two of the items, which are marked in the
document.

**Next steps**
- [ ] **P2** [decide] Go through `dev_notes/codereview_2026-10.md` and pick the items to fix, possibly together with the documentation review (#90).
- [ ] **P3** [claude] Check the two items that #95 may have fixed (`event_ud_level()` with a one-row table of UDs; factor ids in `hr_tt_ud_overlap()`), and update the document.

## ctmm integration

The ctmm models (`ctmm_tt_fit()`, `hr_tt_akde()`, `hr_tt_akde_pop()`), merged
in #84.

**Status.** The plan, its decisions and its later analyses are in
`dev_notes/ctmm_integration.md`. It marks phases 1 and 2 as implemented,
plus the population UDs of phase 4 (`hr_tt_akde_pop()`). The other later
analyses (occurrence, ctmm overlap, speed, simulations) are not started.

**Next steps**
- [ ] **P3** [decide] Which of the later ctmm analyses in `dev_notes/ctmm_integration.md` to add, if any.
