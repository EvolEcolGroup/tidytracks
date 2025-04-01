#' Filter the tracks based on variables from the metadata
#'
#' @param x A move2 object
#' @param ... The identifiers of one or more tracks to select or selection
#' criteria based on track metadata
#' @param .track_id A vector of the ids of the tracks to select
#' @returns A move2 object with only the selected tracks
#' @export

filter_by_meta <- move2::filter_track_data
