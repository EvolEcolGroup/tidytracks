#' Write a tibble of tracks to CSV files
#'
#' This function writes the event table and the metadata table of a
#' 'tidy_tracks' object to CSV files (or one combined CSV file).
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
#'   )
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
            -dplyr::all_of("geometry"), # drop geom column
            -dplyr::all_of(time_col) # drop original time column
          ) |>
          dplyr::mutate(
            date_time = format(
              x[[time_col]],
              "%Y-%m-%d %H:%M:%S %Z" # format date-time column explicitly
            )
          ),
        sf::st_coordinates(x)
      ),
      file = event_file,
      row.names = FALSE
    )
  )
}
