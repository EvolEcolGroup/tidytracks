# tidytracks: summary

Updated 2026-11-18 (manica01). tidytracks has no jobs in
dramanica/claude_jobs: its work is tracked in its own GitHub issues, so the
sections below are by line of work, not by job.

## Attribution and licences (branch `attribution`)

An audit of code borrowed from other packages, and of licences (18 Nov).

**Status.** The branch `attribution` (local, from `dev`) has 14 commits:

- **Rewrites:** the code copied from GPL-3-only packages (`dist_fast()` from
  trip; the MCP helpers from amt), which conflicted with `GPL (>= 3)`, and
  the LoCoH convex hulls adapted from Wikibooks (CC BY-SA). The rewrites
  give identical results; MCP is 15% faster and LoCoH needs up to 8x less
  memory.
- **Notices and credits:** the copyright notices of gganimate, PNPOLY and
  GEOS/JTS (new `inst/COPYRIGHTS`), and the gganimate and move2 authors as
  `ctb`.
- **Removed:** `dev_notes/explorations/temp/`.

R CMD check gives 0 errors and 0 warnings; an independent agent verified
every commit. The report, `dev_notes/code_review_attribution_2026-11.md`,
lists the findings not fixed: the data (left for later by Andrea), method
citations, four bugs also on `dev`, and three possible speed-ups.

**Next steps**
- [ ] **P1** [review] Review `attribution` (the report's list of commits), then push it and open a PR into `dev`.
- [ ] **P1** [collab] Record the owner, permission and licence of the shag data (`inst/extdata/shags_example.csv`, `data-raw/raw_csv/`) and of the wandering albatross data (animations article); remove the two unused files in `inst/extdata/csv_files/`.
- [ ] **P2** [decide] Fix the s2 error of `hr_tt_mcp()` on some lon/lat data (repeated hull vertex)? Recommended: yes, by dropping repeated vertices.
- [ ] **P3** [decide] MCP in C++ (about 10x faster on many tracks, but different vertices in nearly collinear sets)? Recommended: no, unless MCP on many tracks becomes a bottleneck.
- [ ] **P3** [claude] Add the missing method citations and the Esri credit (report, "Findings not fixed").

## Merged on 16-18 Nov: #92 and #82 (PRs #95–#100), developer notes (#99)

PRs #95–#98 (#92: the only column in both the events and the metadata is
the track id) and #100 (#82: isopleths that cannot be drawn are kept as empty
rows with a warning) are merged into `dev`, and so is #99 (`dev_notes/`).
#92 is closed. The designs are in `metadata_and_events.md` and
`isopleths.md`.

**Next steps**
- [ ] **P3** [cleanup] Close #82 (fixed by #100); delete `inbound` on origin; check, then delete, the local branches that were squash-merged (`kde_locoh_fast` by #94, whose content is all in `dev`; `kde_fast`, `locoh`, `locoh_fast`, `benchmark-sizes`).

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
Two related problems were filed as GitHub issues: #81 (open) and #82 (fixed
by #100). #95 may have fixed two of the items, which are marked in the
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
