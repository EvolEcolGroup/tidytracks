#' Initialise tidytracks printing
#'
#' Restores the persistent printing preference when tidytracks is loaded.
#'
#' @param libname Library path in which tidytracks is installed.
#' @param pkgname Package name.
#' @return `NULL`, invisibly.
#' @keywords internal
.onLoad <- function(libname, pkgname) {
  .set_tidytracks_printing(.get_tt_printing_stored())
  invisible(NULL)
}
