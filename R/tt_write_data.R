#' Write a 'tidy_tracks' object to CSV files
#'
#' This function writes the event table and the metadata table of a
#' 'tidy_tracks' object to CSV files (or one combined CSV file).
#'
#' @param x A 'tidy_tracks' object
#' @param file_prefix The file path to write the tables, with the prefix for the
#'   file names. The event table will be saved as '<file_prefix>_events.csv' and
#'   the metadata table as '<file_prefix>_metadata.csv'. If `combined = TRUE`,
#'   the combined table will be saved as '<file_prefix>_combined.csv'.
#' @param combined Logical, whether to write a combined CSV file with both the
#'   event and metadata tables. Default is FALSE.
#' @return Invisibly, the result of the final [utils::write.csv()] call; this
#'   function is primarily called for its side effect of writing CSV files.
#' @export
tt_write_data <- function(x, file_prefix, combined = FALSE) {
  # check that the base path of these files exists
  base_path <- dirname(file_prefix)
  if (!dir.exists(base_path)) {
    stop("The directory ", base_path, " does not exist.")
  }

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
    x <- x |> move2::mt_as_event_attribute(dplyr::any_of(names(show_meta(x))))
    event_file <- paste0(file_prefix, "_combined.csv")
  }


  # Write event table
  time_col <- move2::mt_time_column(x)
  utils::write.csv(
    cbind(
      as.data.frame(x) |>
        dplyr::select(
          -dplyr::all_of("geometry"),  # drop geom column
          -dplyr::all_of(time_col)     # drop original time column
        ) |>
        dplyr::mutate(
          date_time = format(
            x[[time_col]],
            "%Y-%m-%d %H:%M:%S %Z"
          )
        ),
      sf::st_coordinates(x)
    ),
    file = event_file,
    row.names = FALSE
  )
}
