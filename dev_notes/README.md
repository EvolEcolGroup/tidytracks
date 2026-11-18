# tidytracks: developer notes

Notes for developers and Claude sessions; not part of the built package
(`.Rbuildignore`), and not linted (`.lintr`). Scripts that build the
package's data stay in `data-raw/`.

## Living documents

- [summary.md](summary.md): status and next steps, for Andrea.
- [handover.md](handover.md): branches and next tasks, for the next session.
- [progress.md](progress.md): log of major activity, newest first.

## Design

- [metadata_and_events.md](metadata_and_events.md): the rule that only the
  track id is in both the events and the metadata, and the functions that
  keep it (#92, PRs #95–#98).
- [isopleths.md](isopleths.md): isopleths that cannot be drawn are kept as
  empty rows with a warning (#82, PR #100).
- [ctmm_integration.md](ctmm_integration.md): plan and decisions for the
  ctmm models (#84), and the later analyses.

## Reviews

- [codereview_2026-10.md](codereview_2026-10.md): open issues of code review
  2 (#86) that need a decision.
- [code_review_attribution_2026-11.md](code_review_attribution_2026-11.md):
  audit of code borrowed from other packages and of licences (branch
  `attribution`): the rewrites, notices and credits, and the data, citation
  and speed-up findings not fixed.

- `code_review_fpt_2026-11.md` (on branch `codereview_fpt` until it is
  merged): review of the first passage time functions (`fpt`), with the
  fixes, the new defaults, the checks and the findings not fixed.

## Upstream bug reports (drafts)

- [move2_track_data_issue.md](move2_track_data_issue.md): move2
  `group_by_track_data()` and `filter_track_data()` with `sf` track data or
  columns in both tables.
- [move2utils_bridge_kernels_issue/](move2utils_bridge_kernels_issue/README.md):
  out-of-bounds write in the Brownian bridge kernels of move2utils, with a
  patch and reproduction scripts.
- [move2utils_clean_track_thresholds_issue.md](move2utils_clean_track_thresholds_issue.md):
  move2utils `mt_clean_track()` ignores three thresholds with several tracks.

## Explorations (moved from `data-raw/`)

Notebooks and scripts written while developing the package. Some may no
longer run against the current code.

- [explorations/kde_example_data_bba.R](explorations/kde_example_data_bba.R)
  (with its `.rds` data): where `hr_tt_kde()` breaks with a small bounding
  box or a coarse resolution.
- [explorations/kernel_overlaps.Rmd](explorations/kernel_overlaps.Rmd):
  benchmark of the kernel overlap functions.
- [explorations/kernel_randomisation.Rmd](explorations/kernel_randomisation.Rmd):
  a copy of the main vignette, extended with tests of the overlap between the
  UDs of males and females (a Mantel test, and an unfinished randomisation).
- [explorations/move2utils.Rmd](explorations/move2utils.Rmd): draft article,
  "Using move2utils with tidytracks".
- [explorations/tt_regular_time.R](explorations/tt_regular_time.R),
  [explorations/ud_overlap.R](explorations/ud_overlap.R): early versions of
  `tt_regular_time()` and `hr_tt_ud_overlap()`.
- [explorations/old/](explorations/old/): early notebooks on UDs, kernels and
  reading data.

## Helper scripts

- [helper_functions/](helper_functions/): checks of the docs (examples,
  returns), CRAN submission steps (`submitting_to_cran.R`), styling, and
  re-saving `.rds` files. Run them from the root of the package.
