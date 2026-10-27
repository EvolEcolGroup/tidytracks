#' Write a tibble of tracks to CSV files
#'
#' This function writes the event table and the metadata table of a
#' 'tidy_tracks' object to CSV files (or one combined CSV file). Times are
#' written in UTC (e.g. "2024-01-15 13:45:30 UTC", with fractional seconds if
#' any), in the column `date_time`, so that they can be read back with
#' [tt_read_data()].
#'
#' @param x A `move2` object
#' @param file_prefix The file path to write the tables, with the prefix for the
#'   file names. The event table will be saved as '<file_prefix>_events.csv' and
#'   the metadata table as '<file_prefix>_metadata.csv'. If `combined = TRUE`,
#'   the combined table will be saved as '<file_prefix>_combined.csv'.
#' @param combined Logical, whether to write a combined CSV file with both the
#'   event and metadata tables. Default is FALSE.
#' @return Invisibly, the result of the final [utils::write.csv()] call; this
#'   function is primarily called for its side effect of writing CSV files.
#' @export
#' @examples
#' # Save to temp directory
#' tmp_prefix <- file.path(tempdir(), "example_tt_data")
#' tt_write_data(
#'   example_tt,
#'   tmp_prefix,
#'   combined = TRUE
#' )
#'
tt_write_data <- function(x, file_prefix, combined = FALSE) {
  # check that the base path of these files exists
  base_path <- dirname(file_prefix)
  if (!dir.exists(base_path)) {
    stop("The directory ", base_path, " does not exist.")
  }

  # drop any sfc geometry columns (such as colony/nest location) from meta
  show_meta(x) <- show_meta(x) %>%
    dplyr::select(-dplyr::where(~ inherits(.x, "sfc")))

  if (!combined) {
    # Write metadata table
    meta_file <- paste0(file_prefix, "_metadata.csv")
    utils::write.csv(
      show_meta(x),
      file = meta_file,
      row.names = FALSE
    )
    # set the event file name
    event_file <- paste0(file_prefix, "_events.csv")
  } else {
    # move all metadata into events table
    x <- x %>%
      as_event_column(dplyr::any_of(
        # except for any column names that are in both events and meta
        base::setdiff(names(show_meta(x)), names(x))
      ))
    event_file <- paste0(file_prefix, "_combined.csv")
  }

  # Write event table
  time_col <- move2::mt_time_column(x)
  invisible(
    utils::write.csv(
      cbind(
        as.data.frame(x) |>
          dplyr::select(
            -dplyr::all_of(attr(x, "sf_column")), # drop geom column
            -dplyr::all_of(time_col) # drop original time column
          ) |>
          dplyr::mutate(
            date_time = format_date_time_utc(x[[time_col]])
          ),
        sf::st_coordinates(x)
      ),
      file = event_file,
      row.names = FALSE
    )
  )
}

#' Format date-times in UTC
#'
#' Formats date-times in UTC, rather than in their own time zone, as time zone
#' abbreviations (e.g. "BST") cannot be parsed when the data are read back.
#' Fractional seconds are kept (to the microsecond) if there are any.
#'
#' @param time A `POSIXct` vector.
#' @returns A character vector.
#' @keywords internal
#' @noRd
format_date_time_utc <- function(time) {
  seconds <- as.numeric(time)
  time_format <- if (any(seconds != floor(seconds), na.rm = TRUE)) {
    "%Y-%m-%d %H:%M:%OS6 %Z"
  } else {
    "%Y-%m-%d %H:%M:%S %Z"
  }
  format(time, time_format, tz = "UTC")
}
