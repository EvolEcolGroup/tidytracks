#' Deprecated functions in tidytracks
#'
#' These functions have been renamed with an `hr_tt_` prefix to avoid name
#' clashes with other packages. The old names still work for backwards
#' compatibility, but they issue a warning and will be removed in a future
#' release. Please use the new names instead.
#'
#' The deprecated functions and their replacements are:
#'
#' * `hr_kde()`: use [hr_tt_kde()]
#' * `hr_mcp()`: use [hr_tt_mcp()]
#' * `hr_ud_iso()`: use [hr_tt_ud_iso()]
#' * `hr_ud_overlap()`: use [hr_tt_ud_overlap()]
#' * `hr_ud_sum()`: use [hr_tt_ud_sum()]
#' * `hr_ud_wrap()`: use [hr_tt_ud_wrap()]
#' * `hr_ud_unwrap()`: use [hr_tt_ud_unwrap()]
#' * `hr_ud_saveRDS()`: use [hr_tt_ud_saveRDS()]
#'
#' @param x,h,bbox,res,levels,method,... Arguments passed to the replacement
#'   function; see its documentation for details.
#' @return The output of the replacement function.
#' @name tidytracks-deprecated
#' @keywords internal
NULL
