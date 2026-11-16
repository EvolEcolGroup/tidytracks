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
| `dev_notes` | this `dev_notes/`, with the notes moved out of `data-raw/` | `dev` | yes | no (PR #99) |
| `move2utilsbug` | two draft move2utils bug reports, now copied to `dev_notes/` | `main` | yes | no (no PR) |
| `fpt` | Lizzie: first passage time, under review in another session | `dev` | yes | no |
| `get_data_ready_vignette` | Paul: vignette text (January 2026) | — | yes | no |
| `tt_and_move2_diffs` | Holly: wording (September 2026) | — | yes | no |

`benchmark-sizes` and `inbound` were squash-merged (#89, #91), and can be
deleted.

## Next tasks

The next steps of `summary.md`, in the same order and with the same labels.

### 1. **P1** [review] Merge #95, #96, #97 and #98, in this order

- Each branch has the previous ones merged in, so each PR shows their commits
  until they are merged. The PR descriptions list each PR's own commits.
- Before merging, check that CI passes on the last pushes of 16 Nov. The full
  `R CMD check` was last run locally on #95 (0 errors, 0 warnings, 0 notes);
  the later changes were checked with their test files only.
- **Done when:** all four are merged into `dev`, and #92 is closed (or left
  open for `select_by_meta()`).

### 2. **P3** [decide] `select_by_meta()`

- See `metadata_and_events.md`, "Open questions". If wanted, write it on a
  new branch from `dev` after #98, in the style of `filter_by_meta()`, always
  keeping the track id.

### 3. **P3** [cleanup] Branches

- After the merges, delete `group_by_meta`, `colname_functions`,
  `no_duplicated_columns`, `geom_meta_columns`, `benchmark-sizes` and
  `inbound` on origin, and `move2utilsbug` once its reports are filed.

### 4. **P2** [review] Merge #99 (`dev_notes`)

- It does not depend on #95–#98. After it is merged, update this handover on
  the branch being worked on.

### 5. **P2** [andrea] File the upstream reports

- Rerun the example in `move2_track_data_issue.md` with the latest move2, and
  update its output.
- File the move2 report (GitLab `bartk/move2`). Then file the two move2utils
  reports (MPCDF GitLab, mirrored at `move2universe/move2utils`), unless they
  are filed already.

### 6. **P2** [decide] Code review 2: open issues

- Read `codereview_2026-10.md`, and pick the items to fix. A fix is one
  branch from `dev` per item, with a test, and a NEWS bullet.

### 7. **P3** [claude] Check the review items that #95 may have fixed

- **Branch:** `dev`, after #95 is merged.
- **Do:** try `event_ud_level()` with a one-row table of UDs and events of
  several tracks, and `hr_tt_ud_overlap()` on a table grouped by a factor.
  Mark the items as fixed in `codereview_2026-10.md`, or file issues.

### 8. **P3** [decide] Later ctmm analyses

- See `ctmm_integration.md`, "Later: further analyses built on the model
  table".

## Desktop queue

None.

## Backlog

- `hr_tt_ud_iso()` and the KDE isopleths: a grouping variable named `level`,
  `area` or `geometry` clashes with the result columns (predates #92).
- Check the deprecation version of `.keep = TRUE` ("0.3.0") at the next
  release.
- Documentation review (#90), which #92 was meant to precede, and the data
  cleaning vignette (#65).
- Open issues #81 (McConnell interpolation) and #82 (isopleth levels).
