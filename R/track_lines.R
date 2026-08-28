#' Return a trajectory line for each track
#'
#' @description Converts each track into one line. This function returns a
#' [`sf::sf`] object with a `LINESTRING` representing the trajectory as geometry
#' for each track, as well as additional columns of information from the
#' metadata table.
#'
#' @param x A move object
#'
#' @param ... Arguments passed on to the [dplyr::summarise()] function
#'
#' @return A [sf::sf] object with a `LINESTRING` representing the track as
#'   geometry for each track. The metadata for each track is included as well as
#'   the products from summarize
#'
#' @details Note that all empty points are removed before summarizing. Arguments
#' passed with `...` thus only summarize for the non empty locations.
#' @export
#' @examples
#' track_lines(example_tt)

track_lines <- move2::mt_track_lines
