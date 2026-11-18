#' Order of the groups of the hr_tt_* functions
#'
#' When `x` is not grouped, the hr_tt_* functions group it by track id, and
#' return the tracks in the order of the metadata, as the track_* functions
#' do; groups set by the user are returned in the order of their keys (i.e.
#' sorted by the grouping variables). Per-group values (e.g. a bandwidth per
#' group) are matched to the groups in the same order.
#'
#' @param x A grouped move2 object.
#' @param by_track Whether `x` was grouped by track id by the hr_tt_*
#'   function, as it was not grouped.
#' @returns The indices of the groups (i.e. of the rows of
#'   [dplyr::group_keys()]) in the order in which they are returned.
#' @keywords internal
#' @noRd
hr_group_order <- function(x, by_track) {
  n_groups <- dplyr::n_groups(x)
  if (!by_track) {
    return(seq_len(n_groups))
  }
  group_order <- match(
    show_meta(x)[[move2::mt_track_id_column(x)]],
    dplyr::group_keys(x)[[1]]
  )
  # tracks of the metadata without events have no group
  group_order[!is.na(group_order)]
}

#' Keys of the groups of the hr_tt_* functions
#'
#' The hr_tt_* functions return the keys of the groups (the values of the
#' grouping variables, with their own types, e.g. a factor or an `sfc` column
#' of points) as the first columns of their results, one per grouping
#' variable, followed by the column `method`.
#'
#' @param x A grouped move2 object.
#' @param group_order The order of the groups, from `hr_group_order()`.
#' @returns A tibble with the keys of the groups, one row per group, in the
#'   order in which they are returned.
#' @keywords internal
#' @noRd
hr_group_keys <- function(x, group_order) {
  dplyr::group_keys(x)[group_order, , drop = FALSE]
}

#' Text labels of the groups of the hr_tt_* functions
#'
#' The labels name the UDs of the hr_tt_* functions, identify the groups in
#' their messages, and identify the rows of their tables (e.g. in
#' [hr_tt_ud_overlap()]).
#'
#' @param keys A table with the keys of the groups, one column per grouping
#'   variable (e.g. from `hr_group_keys()`).
#' @returns A character vector with one label per row of `keys`: the values of
#'   its columns separated by "_", with `sfc` columns written as WKT (e.g.
#'   "POINT (0 10)").
#' @keywords internal
#' @noRd
hr_group_labels <- function(keys) {
  # a table of isopleths keeps its geometry when its columns are selected
  if (inherits(keys, "sf")) {
    keys <- sf::st_drop_geometry(keys)
  }
  keys <- dplyr::ungroup(keys)
  for (col in names(keys)) {
    if (inherits(keys[[col]], "sfc")) {
      # write each distinct location once (there may be one per event)
      locations <- vctrs::vec_unique(keys[[col]])
      keys[[col]] <- sf::st_as_text(locations)[
        vctrs::vec_match(keys[[col]], locations)
      ]
    }
  }
  tidyr::unite(keys, col = "group_labels") %>%
    dplyr::pull(1)
}

#' Add the keys of the groups to the results of the hr_tt_* functions
#'
#' @param keys A table with the keys of the groups, one row per group (from
#'   `hr_group_keys()`).
#' @param results A table with the results, with `each` rows per group (e.g.
#'   one per level), group after group.
#' @param each The number of rows of `results` per group.
#' @returns `results`, with the keys of their groups as their first columns.
#' @keywords internal
#' @noRd
hr_with_keys <- function(keys, results, each = 1) {
  # a grouping variable named like a column of the results would replace it
  clashes <- intersect(names(keys), names(results))
  if (length(clashes) > 0) {
    stop(
      "the grouping variable(s) (or the track id column) cannot be named ",
      "like a column of the result (",
      paste0("\"", names(results), "\"", collapse = ", "),
      "); rename ", paste0("\"", clashes, "\"", collapse = ", "), " first",
      call. = FALSE
    )
  }
  keys <- keys[rep(seq_len(nrow(keys)), each = each), , drop = FALSE]
  dplyr::bind_cols(keys, results)
}

#' The key columns of a table of home ranges
#'
#' The columns before `method` in the tables returned by the hr_tt_*
#' functions (see `hr_group_keys()`), or the first column of a table without
#' keys before `method` (e.g. a table made by the user).
#'
#' @param x A table of UDs or isopleths.
#' @returns The names of the key columns of `x`.
#' @keywords internal
#' @noRd
hr_key_columns <- function(x) {
  method_col <- match("method", names(x))
  if (is.na(method_col) || method_col == 1) {
    return(names(x)[1])
  }
  names(x)[seq_len(method_col - 1)]
}
