#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang .data
#' @importFrom rlang !!
#' @importFrom rlang !!!
#' @importFrom Rcpp sourceCpp
#' @useDynLib tidytracks, .registration = TRUE
## usethis namespace: end
NULL

# lwgeom is never called directly, but package functions need it through
# other packages: sf::st_distance() uses it for lon/lat data when s2 is
# switched off (event_distance(), and so track_tot_distance(), event_speed()
# and track_summary_stats()), and move2::mt_azimuth() always uses it
# (event_azimuth()). Importing one function records the dependency.
#' @importFrom lwgeom st_geod_azimuth
NULL

#' @importFrom move2 mt_as_move2
#' @export
move2::mt_as_move2

#' @importFrom units as_units
#' @export
units::as_units
