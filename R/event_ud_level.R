#' Find the isopleth level of each event in a utilisation distribution
#'
#' This function returns, for each event, the level of the smallest isopleth
#' of a utilisation distribution (UD) that contains its location, i.e. the
#' proportion of the UD in the cells with a density at least as high as the
#' cell of the event. Values near 0 indicate events in the core of the UD;
#' values near 1 indicate events in its periphery (e.g. an event with a value
#' of 0.6 lies outside the 50% home range but inside the 95% one). It is a
#' wrapper around [move2utils::ud_outer_probability()], which requires the
#' suggested package `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' `ud` can be a single UD, used for all events, or a tibble of UDs (of class
#' `hr_tt_ud_tbl`, as returned by e.g. [hr_tt_kde()] or [hr_tt_dbbmm()]). With
#' a tibble, the level of each event is computed in the UD of its own row,
#' matching the first column of the tibble (e.g. the track id) to the column
#' of `x` with the same name; a tibble with a single row is used for all
#' events.
#'
#' Events are reprojected to the coordinate reference system of the UD if
#' needed. Events without a location, outside the grid of the UD, or without
#' a matching UD get `NA`.
#'
#' @param x A `move2` object.
#' @param ud A UD, either as a `terra::SpatRaster` (with a layer named `ud`, or
#'   a single layer), or as a tibble of class `hr_tt_ud_tbl`.
#' @returns A numeric vector with one value per event of `x`, between 0 and 1.
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' ud <- hr_tt_kde(example_tt)
#' # the level of each event in the UD of its own track
#' event_ud_level(example_tt, ud)
#' # the level of each event in the UD of track "a"
#' event_ud_level(example_tt, ud$ud[["a"]])
event_ud_level <- function(x, ud) {
  check_move2utils("event_ud_level") # nolint: object_usage_linter.
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  located <- !sf::st_is_empty(x)
  level <- rep(NA_real_, nrow(x))

  if (inherits(ud, "SpatRaster")) {
    level[located] <- ud_level_one(x[located, ], ud)
  } else if (inherits(ud, "hr_tt_ud_tbl")) {
    ud <- hr_tt_ud_unwrap(ud) # nolint: object_usage_linter.
    if (nrow(ud) == 1) {
      level[located] <- ud_level_one(x[located, ], ud$ud[[1]])
    } else {
      id_col <- names(ud)[1]
      if (!id_col %in% names(x)) {
        stop(
          "the first column of ud ('", id_col, "') must be a column of x, ",
          "to match each event to its UD; use as_event_column() to move it ",
          "from the metadata"
        )
      }
      event_ids <- as.character(x[[id_col]])
      for (i in seq_len(nrow(ud))) {
        events <- located & event_ids %in% as.character(ud[[1]][i])
        if (any(events)) {
          level[events] <- ud_level_one(x[events, ], ud$ud[[i]])
        }
      }
    }
  } else {
    stop("ud must be a SpatRaster or an hr_tt_ud_tbl")
  }
  level
}

#' Find the isopleth level of events in a single UD
#'
#' @param x A `move2` object, without events with an empty geometry.
#' @param ud A `SpatRaster` with a layer named `ud`, or a single layer.
#' @returns A numeric vector with one value per event of `x`.
#' @keywords internal
#' @noRd
ud_level_one <- function(x, ud) {
  if ("ud" %in% names(ud)) {
    ud <- ud[["ud"]]
  } else if (terra::nlyr(ud) != 1) {
    stop("ud must have a layer named 'ud', or a single layer")
  }
  move2utils::ud_outer_probability(x, ud)
}
