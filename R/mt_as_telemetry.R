#' Convert a `move2` object to a list of `ctmm` telemetry objects
#'
#' This function converts a tibble of tracks (a `move2` object) into the
#' `telemetry` objects used by the package `ctmm` to fit continuous-time
#' movement models. One `telemetry` object is created for each track, and the
#' objects are returned as a list named by track id, in the same order as the
#' tracks in the metadata (see [show_meta()]). The reverse conversion is
#' provided by [move2::mt_as_move2()].
#'
#' @details `ctmm` requires coordinates in a projected coordinate reference
#'   system (CRS) with units in metres. If `x` is in longitude/latitude, it
#'   should first be projected with [sf::st_transform()]; an appropriate CRS for
#'   the area covered by the tracks can be found with
#'   `crstools::suggest_crs()`. The `telemetry` objects use the CRS of `x`,
#'   and their `x` and `y` columns are the coordinates of `x`, so that any
#'   object estimated by `ctmm` (e.g. a utilisation distribution) is aligned
#'   with the original data.
#'
#'   Events with an empty geometry (i.e. no location) are dropped, and so are
#'   tracks without any location.
#'
#'   Only the track id, time and location of each event are passed to
#'   `ctmm` by default, plus any columns with information on location error
#'   (e.g. GPS dilution of precision or Argos location classes) that `ctmm`
#'   can use in an error model (see `error_cols`). Other columns are not passed
#'   as `ctmm` identifies columns by name, so that a column such as
#'   `tag_local_identifier` could be mistaken for the id of the track.
#'
#' @param x A `move2` object, in a projected CRS with units in metres.
#' @param error_cols The columns of the event data with information on the
#'   error of the locations, to be passed to `ctmm`. If `"auto"` (the
#'   default), the columns with a name that `ctmm` recognises as error
#'   information (with Movebank naming, e.g. `gps_hdop`,
#'   `eobs_horizontal_accuracy_estimate`, `argos_lc`) are passed. Otherwise, a
#'   character vector of column names, or `NULL` to pass no error information.
#'   `ctmm` ignores columns with names that it does not recognise (see
#'   [ctmm::as.telemetry()]); such columns can be renamed by naming the
#'   vector with the names used by `ctmm`, e.g.
#'   `error_cols = c(HDOP = "my_hdop_column")`.
#' @param ... Additional arguments passed to [ctmm::as.telemetry()] (e.g.
#'   `timeout` or `dt.hot`).
#' @returns A list of `ctmm` `telemetry` objects, one per track (with at least
#'   one location), named by track id and in the order of the metadata.
#' @export
#' @examplesIf rlang::is_installed("ctmm")
#' # the buffalo dataset from ctmm, converted to a tibble of tracks
#' data(buffalo, package = "ctmm")
#' buffalo_tt <- mt_as_move2(buffalo)
#' # and converted back to a list of telemetry objects
#' buffalo_tel <- mt_as_telemetry(buffalo_tt)
#' names(buffalo_tel)
mt_as_telemetry <- function(x, error_cols = "auto", ...) {
  check_ctmm_installed()
  # Check if x is a move2 object
  if (!inherits(x, "move2")) {
    stop("x must be a move2 object")
  }
  # ctmm only works with metric projected coordinates
  check_ctmm_crs(x)
  # the time column must be a proper date-time (ctmm needs absolute times)
  if (!inherits(event_time(x), "POSIXct")) {
    stop(
      "the time column of x must be of class POSIXct to be used with ctmm"
    )
  }
  # we work on the full set of events, ignoring any grouping
  x <- dplyr::ungroup(x)
  # the track ids in the order of the metadata (used to order the output)
  meta_ids <- as.character(show_meta(x)[[move2::mt_track_id_column(x)]])
  # the names of the columns with information on the location error
  error_cols <- ctmm_error_cols(x, error_cols)

  ## select and sort the events to pass to ctmm
  # events with an empty geometry have no location to pass to ctmm
  located <- which(!sf::st_is_empty(x))
  if (length(located) == 0) {
    stop("x has no events with a location")
  }
  # ctmm warns if the times are not sorted within each track, so we sort the
  # located events by track and time; `rows` are their indices in x
  track_id <- as.character(event_track_id(x))
  time <- event_time(x)
  rows <- located[order(track_id[located], time[located])]
  # time in UTC, as ctmm uses the time zone of the first event for all
  time <- time[rows]
  attr(time, "tzone") <- "UTC"
  # the projected coordinates of x, and the same locations in longitude and
  # latitude (WGS84), which is what ctmm expects (it then projects them
  # itself)
  xy <- sf::st_coordinates(x)[rows, , drop = FALSE]
  long_lat <- sf::st_coordinates(
    sf::st_transform(sf::st_geometry(x)[rows], 4326)
  )

  ## build the data.frame passed to ctmm
  # ctmm identifies columns by name, so we use names that it recognises
  # (based on the Movebank naming conventions); ctmm sorts the events again
  # (with a sort that does not preserve the order of ties), so we add an
  # index column, which we use to recover the original coordinates of each
  # event (as the index makes every row unique, it also stops ctmm from
  # silently dropping duplicated events)
  ctmm_df <- data.frame(
    individual.local.identifier = track_id[rows],
    timestamp = time,
    location.long = long_lat[, 1],
    location.lat = long_lat[, 2],
    tt_row_index = seq_along(rows)
  )
  # add the error columns as plain numbers, dropping units (ctmm expects
  # numbers in metres for error estimates, and unitless values for dilutions
  # of precision)
  if (length(error_cols) > 0) {
    error_df <- sf::st_drop_geometry(x)[rows, error_cols, drop = FALSE]
    error_df <- as.data.frame(lapply(error_df, function(col) {
      if (inherits(col, c("units", "integer64"))) as.numeric(col) else col
    }))
    # the columns take the names given to error_cols, if any (e.g.
    # c(HDOP = "my_hdop_column")), so that ctmm recognises them; unnamed
    # columns keep their own name
    error_names <- rlang::names2(error_cols)
    unnamed <- error_names == ""
    error_names[unnamed] <- error_cols[unnamed]
    names(error_df) <- error_names
    ctmm_df <- cbind(ctmm_df, error_df)
  }

  ## create the telemetry objects
  # ctmm::as.telemetry() sets options(digits.secs = 6), which would change how
  # date-times are printed for the rest of the session, so we restore the
  # option when we are done
  old_options <- options(digits.secs = getOption("digits.secs"))
  on.exit(options(old_options), add = TRUE)
  # one object per track, in the CRS of x (drop = FALSE always returns a
  # list, even for a single track); we keep the index column to match the
  # rows of each object to the events of x
  tel_list <- ctmm::as.telemetry(
    ctmm_df,
    projection = sf::st_crs(x),
    keep = "tt_row_index",
    drop = FALSE,
    ...
  )
  # ctmm projects the longitude and latitude using its own (PROJ4)
  # representation of the CRS, which can lose details of the datum; we replace
  # its coordinates with the original ones, so that everything estimated by
  # ctmm is aligned with x
  tel_list <- lapply(tel_list, function(tel) {
    tel$x <- xy[tel$tt_row_index, 1]
    tel$y <- xy[tel$tt_row_index, 2]
    tel$tt_row_index <- NULL
    tel
  })

  # return the tracks in the order of the metadata (ctmm sorts them
  # alphabetically); tracks without locations are not in tel_list
  tel_list[intersect(meta_ids, names(tel_list))]
}

#' Check that x has a CRS that can be used with ctmm
#'
#' `ctmm` requires coordinates in a projected CRS with units in metres. This
#' function gives an informative error (suggesting how to project the data)
#' otherwise.
#'
#' @param x A `move2` object.
#' @returns `NULL`, invisibly, if the CRS of `x` is suitable.
#' @keywords internal
#' @noRd
check_ctmm_crs <- function(x) {
  crs <- sf::st_crs(x)
  if (is.na(crs)) {
    stop(
      "x has no coordinate reference system (CRS); set one with ",
      "`sf::st_set_crs()`",
      call. = FALSE
    )
  }
  # longitude/latitude (the CRS of most raw tracking data) gets its own
  # message; a projected CRS can still have units other than metres (e.g.
  # US survey feet)
  if (isTRUE(sf::st_is_longlat(x))) {
    stop(
      "ctmm requires x to be in a projected coordinate reference system ",
      "(not longitude/latitude); project x with `sf::st_transform()`, e.g. ",
      "using the projection suggested by `crstools::suggest_crs(x)` for the ",
      "area covered by the tracks",
      call. = FALSE
    )
  }
  if (!identical(crs$units, "m")) {
    stop(
      "ctmm requires x to be in a projected coordinate reference system with ",
      "units in metres; project x with `sf::st_transform()`, e.g. using the ",
      "projection suggested by ",
      "`crstools::suggest_crs(sf::st_transform(x, 4326))` for the area ",
      "covered by the tracks",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Check that ctmm is installed
#'
#' @returns `NULL`, invisibly, if `ctmm` is installed; an error otherwise.
#' @keywords internal
#' @noRd
check_ctmm_installed <- function() {
  # ctmm is only a suggested package, so it might not be installed
  if (!requireNamespace("ctmm", quietly = TRUE)) {
    stop(
      "to use this function, first install package 'ctmm' with\n",
      "install.packages('ctmm')",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Find the columns with location error information to pass to ctmm
#'
#' `ctmm` identifies columns by their name, after removing separators and
#' converting to lower case (so that e.g. `gps_hdop` and `GPS.HDOP` are
#' equivalent). The names below are the subset of the names recognised by
#' `ctmm::as.telemetry()` that provide information on location error, leaving
#' out very generic names (e.g. `error` or `quality`) which might be used for
#' other purposes.
#'
#' @param x A `move2` object.
#' @param error_cols Either `"auto"`, a character vector of column names, or
#'   `NULL`.
#' @returns A character vector of column names of `x` (possibly empty); the
#'   names given to `error_cols`, if any, are kept.
#' @keywords internal
#' @noRd
ctmm_error_cols <- function(x, error_cols) {
  # NULL means that no error information is passed
  if (is.null(error_cols)) {
    return(character(0))
  }
  if (!is.character(error_cols)) {
    stop("error_cols must be \"auto\", a character vector or NULL")
  }
  # the event columns (excluding the geometry)
  event_cols <- setdiff(names(x), attr(x, "sf_column"))
  # with "auto", we pick the event columns that ctmm would recognise as
  # error information
  if (identical(error_cols, "auto")) {
    known_error_cols <- c(
      # error estimates (in metres)
      "eobs.horizontal.accuracy.estimate",
      "eobs.horizontal.accuracy.estimate.m",
      "gps.horizontal.accuracy.estimate",
      "gps.horizontal.accuracy.estimate.m",
      "horizontal.accuracy.estimate",
      "horizontal.accuracy.estimate.m",
      "location.error",
      "location.error.m",
      "coordinate.uncertainty.in.meters",
      "gps.horizontal.error",
      "telonics.horizontal.error",
      # dilution of precision
      "gps.hdop",
      "hdop",
      "gps.dop",
      "dop",
      "gps.pdop",
      "pdop",
      "gps.gdop",
      "gdop",
      # number of satellites and type of fix
      "gps.satellite.count",
      "satellite.count",
      "gps.fix.type",
      "gps.fix.type.raw",
      "fix.type",
      # Argos location class and error ellipses
      "argos.lc",
      "argos.location.class",
      "argos.semi.major",
      "argos.semi.minor",
      "argos.orientation",
      "argos.error.radius"
    )
    # names are compared in the canonical form used by ctmm (e.g. gps_hdop
    # matches gps.hdop)
    is_error_col <- canonical_ctmm_name(event_cols) %in%
      canonical_ctmm_name(known_error_cols)
    return(event_cols[is_error_col])
  }
  # otherwise, check that the requested columns exist (their names, if any,
  # are only used to rename them when they are passed to ctmm)
  missing_cols <- setdiff(error_cols, event_cols)
  if (length(missing_cols) > 0) {
    stop(
      "error_cols not found in the event data of x: ",
      paste(missing_cols, collapse = ", ")
    )
  }
  error_cols
}

#' Canonical form of a column name, as used by ctmm to match columns
#'
#' @param x A character vector of column names.
#' @returns The names without separators and brackets, and in lower case.
#' @keywords internal
#' @noRd
canonical_ctmm_name <- function(x) {
  # as ctmm's canonical.name(), remove separators (. : _ space -) and round,
  # square and full-width brackets
  tolower(gsub("[.:_ ()\\[\\]\uff08\uff09-]", "", x, perl = TRUE))
}
