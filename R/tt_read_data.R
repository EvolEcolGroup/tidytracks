#' Read the events from a csv file into a `move2` object
#'
#' This function reads a csv file containing event data and converts it into a
#' `move2` object. The csv file should contain contain at least the following
#' columns:
#'
#' - one column which is the `track_id` (i.e. the variable that groups events into a track)
#' - two columns representing the x and y coordinates (e.g. longitude and latitude)
#' - a date-time column (or separate date and time columns)
#'
#' Additional columns of data will be stored in the events table if they have
#' information that is specific to each event (i.e. the values are not unique
#' within a given track), or they will be moved to the meta data table if they
#' are track specific (e.g. bird_id, sex of the individual, colony coordinates,
#' breeding status, etc.).
#'
#' @details This function makes a number of assumptions about the data. If your
#'   data does not meet these assumptions, you may need to preprocess it before
#'   using this function, or create a `move2` object manually using the
#'   `move2::mt_as_move2()` function. See the `reading_data` vignette for more
#'   details.
#'
#' @param events_csv A path to a csv file containing the event data.
#' @param col_track_id The name of the column in the csv file that contains the
#'   track id.
#' @param col_coords A vector of the x and y coordinate column names in the csv
#'   file.
#' @param col_date_time The name of the column in the csv file that contains the
#'   date-time information (or a vector of two elements, the names of separate
#'   date and time columns). Time is assumed to be in UTC.
#' @param crs a proj4 string or EPSG code defining the coordinate reference
#'   system of the data. Defaults to `4326` (WGS 84).
#' @param time_zone a character string specifying the time zone of the
#'   date-time. Defaults to `"UTC"`.
#' @param convert_meta a boolean on whether to attempt to transfer information
#'   in the events table that is track specific (e.g. bird id or colony
#'   coordinates) to the meta data table. Defaults to `TRUE`.
#' @param meta_csv A path to a csv file containing the meta data. If provided,
#'   this will be used to populate the meta data table. It needs to have a
#'   column with the track ids which includes all the track ids in the events
#'   table (additional track ids will be discarded).
#' @return A `move2` object containing the event data.
#' @examples
#' example_events_csv <- system.file("/extdata/csv_files/dataset_example_birdlife.csv",
#' package = "tidytracks")
#' example_tt <- tt_read_data(example_events_csv, col_track_id = "track_id",
#'   col_coords = c("longitude", "latitude"),
#'   col_date_time = c("date_gmt", "time_gmt"))
#' @export

tt_read_data <- function(events_csv,
                           col_track_id,
                           col_coords,
                           col_date_time,
                           crs = 4326,
                           time_zone = "UTC",
                           convert_meta = TRUE,
                           meta_csv = NULL) {
  # Read the events data from the csv file
  events_data <- utils::read.csv(events_csv, stringsAsFactors = FALSE)

  # Check if the required columns are present
  if (!col_track_id %in% names(events_data)) {
    stop(paste("Column", col_track_id, "not found in the events data."))
  } else {
    # Ensure col_track_id is a factor
    events_data[[col_track_id]] <- as.factor(events_data[[col_track_id]])
  }
  if (!all(col_coords %in% names(events_data))) {
    stop(paste("Columns", paste(col_coords, collapse = ", "), "not found in the events data."))
  }
  # check that the col_data_time exist
  if (length(col_date_time) == 1 && !col_date_time %in% names(events_data)) {
    stop(paste("Column", col_date_time, "not found in the events data."))
  } else if (length(col_date_time) == 2 && 
             (!col_date_time[1] %in% names(events_data) || 
              !col_date_time[2] %in% names(events_data))) {
    stop(paste("Columns", paste(col_date_time, collapse = ", "), "not found in the events data."))
  }
  
  # check that col_date_time is either a single character or a vector of two characters
  if (!is.character(col_date_time) || length(col_date_time) < 1 || length(col_date_time) > 2) {
    stop("col_date_time must be a character vector of length 1 or 2.")
  }

  # Convert date and time to POSIXct
  if (length(col_date_time) == 1) {
    events_data[[col_date_time]] <- as.POSIXct(events_data[[col_date_time]], tz = time_zone)
  } else {
    events_data$date_time <- as.POSIXct(paste(events_data[[col_date_time[1]]], 
                                               events_data[[col_date_time[2]]]), tz = time_zone)
    # remove the old date and time columns
    events_data <- events_data %>%
      dplyr::select(-dplyr::all_of(col_date_time))
    col_date_time <- "date_time"  # update col_date_time to the new column name
  }

  # Create a move2 object
  move2_obj <- move2::mt_as_move2(
    sf::st_as_sf(events_data, coords = col_coords, crs = 4326),
    time_column = col_date_time,
    track_id_column = col_track_id
  )

  # Convert track-specific attributes to meta data if requested
  if (convert_meta) {
    # Identify columns that might contain track specific info (i.e. unique within a track)
    candidate_cols <- setdiff(names(events_data), c(col_track_id, col_coords, col_date_time))
    to_move_cols <- c()
    if (length(candidate_cols) > 0) {
      # Check if these columns are unique within each track
      for (col in candidate_cols) {
        # Check if the column is unique within each level of the track id column
        is_unique <- all(tapply(events_data[[col]], events_data[[col_track_id]], function(x) length(unique(x)) == 1))
        if (is_unique){ # if unique within each track, add to list to move to meta
          to_move_cols <- c(to_move_cols, col)
        }
      }
      if (length(to_move_cols) > 0) {
        move2_obj <- move2::mt_as_track_attribute(move2_obj, dplyr::any_of(to_move_cols))
      }
    }

  }

  # If meta_csv is provided, read and merge meta data
  if (!is.null(meta_csv)) {
    new_meta <- utils::read.csv(meta_csv, stringsAsFactors = FALSE)
    if (!col_track_id %in% names(new_meta)) {
      stop(paste("Column", col_track_id, "not found in the meta data."))
    }
    old_meta <- show_meta(move2_obj)
    updated_meta <- dplyr::left_join(old_meta, new_meta, by = col_track_id)
    move2_obj <- move2::mt_set_track_data(move2_obj, updated_meta)
  }

  return(move2_obj)
}
