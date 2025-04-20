#' A move2 object of boobies trajectories
#'
#' A GPS tracking data set of Masked Boobies during incubation and chick
#' rearing at St. Helena Island. The version of the data set used here has
#' been doctored to illustrate the functionalities of the package; in other
#' words, some fo the data have been changed, and this dataset should not be
#' used for any biological analysis.
#'
#' @format An move2 object with 178006 rows and 3 columns
#' \describe{
#'   \item{bird_id}{ids of each bird}
#'   \item{date_time}{time stamp for each event}
#'   \item{geometry}{longitudes and latitudes, as an `sf` geometry for each event}
#' }
"boobies_mt"
