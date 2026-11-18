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
#' matching the columns that identify the UDs (the columns before `method`,
#' i.e. the track id or the grouping variables used to estimate them, or else
#' the first column of the tibble) to the columns of `x` with the same names;
#' a tibble with a single row is used for all events.
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
  # events without a location have no cell in the UD, so they keep NA (as do
  # events without a matching UD); the others are filled in below
  located <- !sf::st_is_empty(x)
  level <- rep(NA_real_, nrow(x))

  if (inherits(ud, "SpatRaster")) {
    level[located] <- ud_level_one(x[located, ], ud)
  } else if (inherits(ud, "hr_tt_ud_tbl")) {
    # a table read back from disk has its UDs wrapped
    ud <- hr_tt_ud_unwrap(ud) # nolint: object_usage_linter.
    if (nrow(ud) == 1) {
      # e.g. the UD of a single track, or the sum of all UDs from
      # hr_tt_ud_sum(), whose first column is not an id
      level[located] <- ud_level_one(x[located, ], ud$ud[[1]])
    } else {
      # the rows of a UD table are identified by its keys, i.e. the columns
      # before `method` (the track id for hr_tt_kde() and hr_tt_dbbmm(), or
      # the grouping variables), or by its first column if it has no keys
      key_cols <- hr_key_columns(ud) # nolint: object_usage_linter.
      missing_cols <- setdiff(key_cols, names(x))
      if (length(missing_cols) > 0) {
        stop(
          "the column(s) that identify the UDs of ud (",
          paste0("'", missing_cols, "'", collapse = ", "),
          ") must be columns of x, to match each event to its UD; use ",
          "as_event_column() or group_by_meta() to move them from the metadata"
        )
      }
      # ids are compared as their labels (as characters, with locations as
      # WKT), whatever the types of the columns in x (e.g. a factor track id)
      event_keys <- tibble::as_tibble(lapply(
        stats::setNames(key_cols, key_cols),
        function(col) x[[col]]
      ))
      event_ids <- hr_group_labels(event_keys) # nolint: object_usage_linter.
      ud_ids <- hr_group_labels(ud[key_cols]) # nolint: object_usage_linter.
      for (i in seq_len(nrow(ud))) {
        # %in% rather than ==, so that events with a missing id are not
        # selected
        events <- located & event_ids %in% ud_ids[i]
        # each UD is used only for its own events, whose levels are computed
        # in one call (move2utils computes the volume of the UD each time)
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
  # move2utils needs a single layer; UDs from tidytracks have a layer named
  # "ud", but other single-layer rasters (e.g. from move2utils) work too
  if ("ud" %in% names(ud)) {
    ud <- ud[["ud"]]
  } else if (terra::nlyr(ud) != 1) {
    stop("ud must have a layer named 'ud', or a single layer")
  }
  # move2utils reprojects the events to the crs of the UD, and gives NA for
  # events outside the grid
  level <- move2utils::ud_outer_probability(x, ud)
  # the levels are cumulative sums of the UD, which can exceed 1 by rounding
  # (e.g. on Apple silicon, where R has no extended precision for sum()), so
  # they are kept between 0 and 1, as they are proportions
  pmin(pmax(level, 0), 1)
}
