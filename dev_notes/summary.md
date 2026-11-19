# tidytracks: summary

Updated 2026-11-19 (manica01). tidytracks has no jobs in
dramanica/claude_jobs: its work is tracked in its own GitHub issues, so the
sections below are by line of work, not by job.

## Attribution and licences (PR #102)

An audit of code borrowed from other packages, and of licences (18-19 Nov).

**Status.** PR #102 (`attribution` into `dev`) was squash-merged on 19 Nov
(`a433574`): 15 fix commits, plus the notes:

- **Rewrites:** the code copied from GPL-3-only packages (`dist_fast()` from
  trip; the MCP helpers from amt), which conflicted with `GPL (>= 3)`, and
  the LoCoH convex hulls adapted from Wikibooks (CC BY-SA). The rewrites
  give identical results; MCP is 15% faster and LoCoH needs up to 8x less
  memory.
- **Notices and credits:** the copyright notices of gganimate, PNPOLY and
  GEOS/JTS (new `inst/COPYRIGHTS`), and the gganimate and move2 authors as
  `ctb`.
- **Fix:** an s2 error of `hr_tt_mcp()` with duplicated lon/lat locations (a
  bug also on `dev`).

R CMD check gives 0 errors and 0 warnings; an independent agent verified
every commit. The report, `dev_notes/code_review_attribution_2026-11.md`,
lists the findings not fixed. The questions on the data are in
`dev_notes/note_for_Lizzie.md`; the C++ MCP is parked in
`dev_notes/mcp_cpp.md` (Andrea, 19 Nov).

**Next steps**
- [x] **P1** [review] Review and merge PR #102 (the report's list of commits); check that CI passes. *Done: squash-merged 19 Nov, `a433574`.*
- [ ] **P1** [andrea] Send Lizzie `dev_notes/note_for_Lizzie.md` (owners, permissions and licences of the shag and albatross data; the unused files in `inst/extdata/csv_files/`); then a session records the answers, or replaces or removes the data.
- [ ] **P3** [claude] Add the missing method citations, the Esri credit and the wild boar note (report, "Findings not fixed").

## Distances with units (PR #103)

Arguments that are distances were read as plain numbers in the units of the
CRS (metres, feet or degrees, depending on the data); they must now be
`units` objects (19 Nov).

**Status.** PR #103 (`kde_units` into `dev`, 9 commits): `h` and `res` of
`hr_tt_kde()`, `res` of `hr_tt_akde()`, `n` (types `"r"`, `"a"`) and
`buffer` of `hr_tt_locoh()`, the buffers of `tt_split_trips()` and `uere` of
`ctmm_tt_fit()`; plain numbers give an error, and the `h`, `res` and `n`
columns have units. The full suite passes (with move2utils) and R CMD check
gives 0 errors and 0 warnings. `dev`, with PR #102, is merged into it (the
code had no conflicts). The decisions are in `dev_notes/units.md`.

**Next steps**
- [ ] **P2** [review] Review and merge PR #103 (one commit per function; breaking changes listed in NEWS); check that CI passes.

## Events without a location in the cleaning functions (PR #104, #81)

`flag_action = "interpolate"` filled in events that had no location before
cleaning, although they were not flagged (#81).

**Status.** PR #104 (`interpolate_empty` into `dev`, 1 commit, by another
session on 19 Nov), as decided in #81: `event_flag_mcconnell()` and
`event_flag_outliers()` flag events without a location (`FALSE`), as the
thinning functions already did, so `tt_clean_*()` interpolate, null or
remove them with the other flagged events. One change in results:
`flag_action = "remove"` (the default) now removes them. The changed test
files pass; it does not conflict with PR #103.

**Next steps**
- [ ] **P2** [review] Review and merge PR #104 (one commit; the change of results of `flag_action = "remove"` is in NEWS); check that CI passes.

## Merged on 16-18 Nov: #92 and #82 (PRs #95–#100), developer notes (#99)

PRs #95–#98 (#92: the only column in both the events and the metadata is
the track id) and #100 (#82: isopleths that cannot be drawn are kept as empty
rows with a warning) are merged into `dev`, and so is #99 (`dev_notes/`).
#92 is closed, and so is #82 (19 Nov). The designs are in `metadata_and_events.md` and
`isopleths.md`.

**Next steps**
- [ ] **P3** [cleanup] Delete `inbound` on origin; check, then delete, the local branches that were squash-merged (`attribution` by #102, deleted on origin; `kde_locoh_fast` by #94, whose content is all in `dev`; `kde_fast`, `locoh`, `locoh_fast`, `benchmark-sizes`).

## First passage time: review of `fpt` (branch `codereview_fpt`)

Lizzie's first passage time functions (`event_fpt()`, `track_fpt_profile()`,
`track_suggest_ars_scale()`; branch `fpt`), reviewed on 12 real datasets.

**Status.** Branch `codereview_fpt` (from `fpt`; PR #101 into `fpt`) holds
the review's fixes, an exact C++ speed-up (9× faster on a 72k-fix track,
about linear in track length), three new defaults decided by Andrea (radii per
track, at least half of the locations per radius, the highest peak), new
examples and the article "Area-restricted search with first passage time".
The FPTs equal `adehabitatLT::fpt()` exactly; R CMD check is OK (1,694
tests). Report: `dev_notes/code_review_fpt_2026-11.md` on that branch.

**Next steps**
- [ ] **P1** [andrea] Send Lizzie the note (Claude doc "FPT review: note to Lizzie", private until shared), so that she reviews `codereview_fpt`: the article, then the report's list of commits.
- [ ] **P2** [review] Merge #101 into `fpt`, then open a PR of `fpt` into `dev`: expect a small conflict in `.Rbuildignore` (#99 is merged), and add the report to `dev_notes/README.md`.
- [ ] **P3** [cleanup] Delete `codereview_fpt` once #101 is merged.

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
Two related problems were filed as GitHub issues: #81 (PR #104) and #82
(fixed by #100, closed). #95 may have fixed two of the items, which are marked in the
document.

**Next steps**
- [ ] **P2** [decide] Go through `dev_notes/codereview_2026-10.md` and pick the items to fix, possibly together with the documentation review (#90).
- [ ] **P3** [claude] Now that #95 is merged, check the two items that it may have fixed (`event_ud_level()` with a one-row table of UDs; factor ids in `hr_tt_ud_overlap()`), and update the document.

## ctmm integration

The ctmm models (`ctmm_tt_fit()`, `hr_tt_akde()`, `hr_tt_akde_pop()`), merged
in #84.

**Status.** The plan, its decisions and its later analyses are in
`dev_notes/ctmm_integration.md`. It marks phases 1 and 2 as implemented,
plus the population UDs of phase 4 (`hr_tt_akde_pop()`). The other later
analyses (occurrence, ctmm overlap, speed, simulations) are not started.

**Next steps**
- [ ] **P3** [decide] Which of the later ctmm analyses in `dev_notes/ctmm_integration.md` to add, if any.
