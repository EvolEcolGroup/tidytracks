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
