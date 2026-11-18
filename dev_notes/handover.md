# tidytracks: handover

Updated 2026-11-16 (laptopX1). For the next session: read this and
`summary.md` first. History is in `progress.md`; designs are in the topic
documents listed in `README.md`.

## Branches

| branch | purpose | base | pushed | merged |
|---|---|---|---|---|
| `group_by_meta` | #92 item 3: `group_by_meta()`, typed `hr_tt_*()` keys | `dev` | yes | no (PR #95) |
| `colname_functions` | #92 item 1: `colname_*()`, used across the package | `group_by_meta` | yes | no (PR #96) |
| `no_duplicated_columns` | #92 item 2: one column per table, setter check, `.keep` deprecated | `colname_functions` (merged in) | yes | no (PR #97) |
| `geom_meta_columns` | #92 item 4: metadata columns in the geoms, `meta_columns` | `no_duplicated_columns` (merged in) | yes | no (PR #98) |
| `iso_empty_levels` | #82: isopleths that cannot be drawn kept as empty rows, with a warning | `geom_meta_columns` | yes | no (PR #100) |
| `dev_notes` | this `dev_notes/`, with the notes moved out of `data-raw/` | `dev` | yes | no (PR #99) |
| `move2utilsbug` | two draft move2utils bug reports, now copied to `dev_notes/` | `main` | yes | no (no PR) |
| `fpt` | Lizzie: first passage time; reviewed in `codereview_fpt` | `dev` | yes | no |
| `codereview_fpt` | review of `fpt`: fixes, speed-up, new defaults, article; report in `dev_notes/code_review_fpt_2026-11.md` | `fpt` | yes | no (PR #101) |
| `get_data_ready_vignette` | Paul: vignette text (January 2026) | — | yes | no |
| `tt_and_move2_diffs` | Holly: wording (September 2026) | — | yes | no |

`benchmark-sizes` and `inbound` were squash-merged (#89, #91), and can be
deleted.

## Next tasks

The next steps of `summary.md`, in the same order and with the same labels.

### 1. **P1** [review] Merge #95, #96, #97 and #98, in this order

- Each branch has the previous ones merged in, so each PR shows their commits
  until they are merged. The PR descriptions list each PR's own commits.
- All CI jobs pass on the last pushes of 16 Nov. The full `R CMD check` was
  last run locally on #95 (0 errors, 0 warnings, 0 notes); the later changes
  were checked with their test files, and by CI.
- **Done when:** all four are merged into `dev`, and #92 is closed (Andrea
  decided on 16 Nov that there will be no `select_by_meta()`).

### 2. **P3** [cleanup] Branches

- After the merges, delete `group_by_meta`, `colname_functions`,
  `no_duplicated_columns`, `geom_meta_columns`, `iso_empty_levels`,
  `benchmark-sizes` and `inbound` on origin, and `move2utilsbug` once its reports are filed.

### 3. **P1** [review] Merge #100 after #98

- All CI jobs pass, and all the home range test files pass locally.
- The rule and Andrea's decisions are in `isopleths.md`. A new case of an
  isopleth that cannot be drawn should add a reason to
  `isopleth_not_drawn_reason()`, in `R/hr_tt_ud_iso.R`.

### 4. **P1** [andrea] Send Lizzie the note on the FPT review

- The note is the Claude doc "FPT review: note to Lizzie" (private: share it
  first). It points her to the article
  (`vignettes/articles/first_passage_time.Rmd`) and to the report
  (`dev_notes/code_review_fpt_2026-11.md`), both on `codereview_fpt`.
- **Done when:** Lizzie has reviewed the branch and ticked the report's boxes,
  or listed what to change.

### 5. **P2** [review] Merge #101 (`codereview_fpt`) into `fpt`, then `fpt` into `dev`

- `codereview_fpt` is `fpt` plus the review: 28 commits (fixes, each with
  its test where one is possible, the merged speed-up and the report),
  verified by separate agents (the report lists them, and how each was
  checked). R CMD check was OK at `a27a29b` (1,694 tests, 0 lints).
- Conflicts to expect with #99: `.Rbuildignore` (both add `^dev_notes$`), and
  the report must be added to `dev_notes/README.md`.
- The article renders in about 6 s, so it is not precompiled.
- **Done when:** `fpt` is merged into `dev`.

### 6. **P3** [cleanup] Branches of the FPT review

- Delete `codereview_fpt` and `fpt` once merged (the speed-up branch is
  already deleted).

### 7. **P2** [review] Merge #99 (`dev_notes`)

- It does not depend on #95–#98. After it is merged, update this handover on
  the branch being worked on.

### 8. **P2** [andrea] File the upstream reports

- Rerun the example in `move2_track_data_issue.md` with the latest move2, and
  update its output.
- File the move2 report (GitLab `bartk/move2`). Then file the two move2utils
  reports (MPCDF GitLab, mirrored at `move2universe/move2utils`), unless they
  are filed already.

### 9. **P2** [decide] Code review 2: open issues

- Read `codereview_2026-10.md`, and pick the items to fix. A fix is one
  branch from `dev` per item, with a test, and a NEWS bullet.

### 10. **P3** [claude] Check the review items that #95 may have fixed

- **Branch:** `dev`, after #95 is merged.
- **Do:** try `event_ud_level()` with a one-row table of UDs and events of
  several tracks, and `hr_tt_ud_overlap()` on a table grouped by a factor.
  Mark the items as fixed in `codereview_2026-10.md`, or file issues.

### 11. **P3** [decide] Later ctmm analyses

- See `ctmm_integration.md`, "Later: further analyses built on the model
  table".

## Desktop queue

None.

## Backlog

- The FPT review leaves 5 minor findings (report, "Findings not fixed"):
  repeated FPTs for groups that split tracks often, memory for tracks of
  millions of locations, the `trip_na` events after
  `tt_split_trips(complete = FALSE)`, numeric and `units` time columns, and
  two small test and type points.

- `hr_tt_ud_iso()` and the KDE isopleths: a grouping variable named `level`,
  `area` or `geometry` clashes with the result columns (predates #92).
- Check the deprecation version of `.keep = TRUE` ("0.3.0") at the next
  release.
- Documentation review (#90), which #92 was meant to precede, and the data
  cleaning vignette (#65).
- Open issue #81 (McConnell interpolation); #82 (isopleth levels) is fixed by
  #100.
