# Metadata and events

A `move2` object has two tables: the events (one row per location) and the
metadata, or track data (one row per track). tidytracks keeps one rule
between them: **the only column in both tables is the track id**. Columns
move from one table to the other; they are never copied. Issue #92 set this
out in four items, done in PRs #95–#98 (November 2026). The code is in
`R/show_meta.R` (the helpers and the setter), `R/as_event_column.R`,
`R/as_meta_column.R`, `R/group_by_meta.R`, `R/filter_by_meta.R`,
`R/tt_read_data.R`, `R/tt_split_trips.R`, `R/hr_group_order.R` (the group keys
of the `hr_tt_*()` functions) and `R/geom_event_point.R`
(`with_meta_columns()`).

## Design decisions

| decision | alternatives considered | why | date | decided by |
|---|---|---|---|---|
| `group_by_meta()` moves the grouping columns to the events | copy them, as `move2::group_by_track_data()` does | keeps the rule; `as_meta_column()` moves them back | 2026-11-15 | Andrea |
| `hr_tt_*()` return one column per grouping variable, with its own type (factor, `sfc`…), and no `group_id` | keep the text `group_id`; both | an `sfc` key from `group_by_meta()` stays a location; labels (with `sfc` as WKT) only name the UDs | 2026-11-15 | Andrea |
| `colname_track_id()` and `colname_time()` are the move2 functions under tidytracks names, and the package code uses them | keep calling move2 | one vocabulary for users and code (`event_*`, `show_meta()`) | 2026-11-16 | Andrea |
| the duplicate check runs in `tt_read_data()`, `tt_split_trips()`, when columns are moved, and in `show_meta<-` | not in the setter | the setter is the common way to change the metadata | 2026-11-16 | Andrea |
| a column with different values in both tables keeps both, with the metadata one renamed `.meta`, and a warning | an error | what `tt_read_data()` already documented | 2026-11-16 | Andrea |
| `.keep = TRUE` of `as_event_column()`/`as_meta_column()` is soft-deprecated (`lifecycle::deprecate_soft()`, "as of 0.3.0") | keep it; remove it | it breaks the rule, and the setter undoes it; 0.3.0 assumed to be the next release | 2026-11-16 | Andrea (version: Claude) |
| a column that the events are grouped by stays in the events, and is removed from the metadata | the other way round | `dplyr::select()` keeps grouping columns | 2026-11-16 | Claude |
| the geoms add all non-`sfc` metadata columns to the layer by default; `meta_columns` restricts them (`character(0)` adds none) | only the columns in `aes()` | a facet is not visible to the geom; `c()` is `NULL` in R, so "none" needs `character(0)` | 2026-11-16 | Andrea (argument), Claude (`character(0)`) |
| the four PRs are stacked and merged in order (#95, #96, #97, #98); later branches merge the earlier ones rather than being rebased | independent PRs | the items depend on each other; force pushes are blocked | 2026-11-15 | Andrea (order), Claude (merges) |

## How it works

- **Helpers** (`R/show_meta.R`):
  - `event_meta_rows()` gives the metadata row of each event. It uses the
    codes of the factor of track ids when it can, which is much faster for
    many events.
  - `same_column_values()` compares two columns with `vctrs::vec_equal()`
    (`na_equal = TRUE`), after casting them to a common type. Incompatible
    types count as different.
  - `check_same_in_both()` is used before moving columns. It returns the
    shared columns with the same values, and errors on different ones.
  - `drop_duplicated_columns()` is the integrity step of `show_meta<-` and
    `tt_split_trips()`. It never removes the time or geometry column of the
    events.
- **`sf` metadata.** move2 cannot join an `sf` table to the events.
  `plain_meta()` and `with_plain_meta()` make it a plain table, with its
  geometry as an `sfc` column. A geometry named like that of the events
  (usually `geometry`) is renamed `geometry.meta`, with a message.
- **`group_by_meta()`.** It evaluates the grouping on the metadata with
  `dplyr::group_by()`, so named expressions work. It writes the grouping
  columns back to the metadata, moves them with `as_event_column()`, and then
  groups the events. A column already moved to the events gives an error
  that points to `dplyr::group_by()`.
- **Group keys** (`R/hr_group_order.R`):
  - `hr_group_keys()` gives the keys in the order of the groups;
  - `hr_group_labels()` gives the text names of the UDs, with `sfc` written
    as WKT;
  - `hr_with_keys()` binds the keys to the results, and errors if a key is
    named like a result column;
  - `hr_key_columns()` finds the key columns (those before `method`).
- **Geoms.** `with_meta_columns()` adds the metadata columns to the layer data
  only, with `mt_as_event_attribute(.keep = TRUE)`. The user's object is not
  changed.
- **Tests:**
  - `test_show_meta.R`, `test_as_event_column.R`, `test_as_meta_column.R`;
  - `test_group_by_meta.R`, `test_filter_by_meta.R` (including `sf`
    metadata);
  - `test_tt_read_data.R`, `test_tt_split_trips.R`;
  - `test_geom_event_path.R`, and the `hr_tt_*` tests for the typed keys.

## Open questions

- `select_by_meta()`, mentioned when #92 item 3 was planned (it is not in
  #92), is not written. Is it still wanted?
- The upstream move2 issue: the draft is in `move2_track_data_issue.md`, for
  Andrea to file.
- In `hr_tt_ud_iso()` and the KDE isopleths, a grouping variable named
  `level`, `area` or `geometry` would clash with the result columns. This
  edge case predates #92 and is untested.
- Check the deprecation version ("0.3.0") at the next release.
