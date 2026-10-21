#' Check that a grouped object has no groups without events
#'
#' Groups without events (e.g. unused levels of a factor grouped with
#' `.drop = FALSE`, or groups emptied by `dplyr::filter(.preserve = TRUE)`) are
#' listed by [dplyr::group_keys()], which would make it ambiguous which groups
#' per-group values refer to, so they are rejected with an error that shows how
#' to remove them.
#'
#' @param x A grouped data frame (e.g. a grouped move2 object).
#' @returns `NULL`, invisibly, if every group of `x` has events.
#' @keywords internal
#' @noRd
check_no_empty_groups <- function(x) {
  empty <- dplyr::group_size(x) == 0
  if (any(empty)) {
    group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
      dplyr::pull(1)
    group_vars <- dplyr::group_vars(x)
    # quote names that are not syntactic, so that the call can be copied
    non_syntactic <- make.names(group_vars) != group_vars
    group_vars[non_syntactic] <- paste0("`", group_vars[non_syntactic], "`")
    stop(
      "x has groups without events (",
      paste(group_labels[empty], collapse = ", "),
      "), e.g. from grouping by a factor with `.drop = FALSE`; remove them ",
      "by regrouping x with `dplyr::group_by(x, ",
      paste(group_vars, collapse = ", "),
      ", .drop = TRUE)`",
      call. = FALSE
    )
  }
  invisible(NULL)
}
