#' A move2 object of Antarctic shag movements
#' 
#' A GPS tracking data set of Antarctic shags during foraging trips from
#' colonies from the Antarctic Peninsula. The version of the data set used here has been
#' doctored to illustrate the functionalities of the package; in other words,
#' some of the data have been changed, and this dataset should not be used for
#' any biological analysis.
#'
#' @format An move2 object with 7798 events from 9 tracks (one per individual).
#' We have 3 columns
#' \describe{
#'   \item{bird_id}{ids of each bird}
#'   \item{date_time}{time stamp for each event}
#'   \item{geometry}{longitudes and latitudes, as an `sf` geometry
#'   for each event}
#' }
"shags_tt"


#' A simple example move2 object
#' 
#' A very simple dataset of 3 individuals, with 5 observations per individual,
#' used for examples in the package documentation.
#'  
#' @format A move2 object with 15 events from 3 tracks (one per individual).
#' We have 3 columns in the main events table
#' \describe{
#'   \item{track_id}{ids of each track}
#'   \item{date_time}{time stamp for each event}
#'   \item{geometry}{longitudes and latitudes, as an `sf` geometry
#'   for each event}
#' }
#' And a metadata table with 3 rows (one per track) and 2 columns:
#' \describe{
#'   \item{track_id}{ids of each track}
#'   \item{sex}{sex of each individual}
#' }
"example_tt"
