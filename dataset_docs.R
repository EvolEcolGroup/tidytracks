#' A move2 object of boobies trajectories
#'
#' A GPS tracking data set of Masked Boobies during incubatoin and chick
#' rearing at St. Helena Island. The version of the data set used here has
#' been doctored to illustrate the functionalities of the package; in other
#' words, some fo the data have been changed, and this dataset should not be
#' used for any biological analyiss.
#'
#' @format An move2 object with 178006 rows and 3 columns
#' \describe{
#'   \item{deployment_id}{ids of each deployment}
#'   \item{date_time}{time stamp for each event}
#'   \item{geometry}{longitudes and latitudes, as an `sf` geometry for each event}
#' }
"boobies_mt"
