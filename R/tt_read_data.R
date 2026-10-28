#' Read data from a CSV file into a `move2` object
#'
#' @description This function reads a CSV file containing event data
#' (and possibly metadata)
#' and converts it into a `move2` object. The CSV file should contain contain at
#' least the following columns:
#'
#' - one column which is the `track_id` (i.e. the variable that groups
#' events into a track)
#' - two columns representing the x and y coordinates (e.g. longitude
#' and latitude)
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
#'   `move2::mt_as_move2()` function. See the article "Reading and cleaning
#'   data" on the package website for more details, including how to read
#'   date-times in different formats.
#'
#' @param events A path to a CSV file containing the event data, OR a dataframe
#'   in R containing the event data.
#' @param col_track_id The name of the column in the CSV file that contains the
#'   track id.
#' @param col_coords A vector of the x and y coordinate column names in the CSV
#'   file.
#' @param col_date_time The name of the column in the CSV file that contains the
#'   date-time information (or a vector of two elements, the names of separate
#'   date and time columns). Time is assumed to be in UTC.
#' @param format_date_time optional, a string containing the format of the
#'   date-time field(s): either the single date-time column, or the date and
#'   time columns separated by a space, for `as.POSIXct()` to parse the
#'   date-time. If `NULL` (default), a set of common formats will be tried:
#'   a date in ISO format (`%Y-%m-%d`, `%Y/%m/%d`), DMY format (`%d/%m/%Y`,
#'   `%d-%m-%Y`, `%d/%m/%y`, `%d-%m-%y`), or MDY format (`%m/%d/%Y`,
#'   `%m-%d-%Y`, `%m/%d/%y`, `%m-%d-%y`), followed by a time in `%H:%M:%OS` or
#'   `%H:%M`. DMY formats are tried before MDY formats, so a date that is
#'   ambiguous between the two (e.g. `"03/04/2024"`, where both day and month
#'   are valid as either) will be silently parsed as DMY (4 March 2024), not
#'   MDY (3 April 2024). If your dates are in MDY format and could be
#'   ambiguous, specify `format_date_time` explicitly rather than relying on
#'   auto-detection. For help with specifying date-time formats, see
#'   `?strptime`.
#' @param crs a proj4 string or EPSG code defining the coordinate reference
#'   system of the data. Defaults to `4326` (WGS 84).
#' @param time_zone a character string specifying the time zone of the
#'   date-time. Defaults to `"UTC"`.
#' @param convert_meta a boolean on whether to attempt to transfer information
#'   in the events table that is track specific (e.g. bird id or colony
#'   coordinates) to the meta data table. Defaults to `TRUE`.
#' @param meta A path to a csv file containing the meta data, OR a dataframe in
#'   R containing the metadata. If provided, this will be used to populate the
#'   meta data table. It needs to have a column with the track ids which
#'   includes all the track ids in the events table (additional track ids will
#'   be discarded). If a column exists in both the events table and the metadata
#'   table, the values will be compared: when identical, the duplicate is
#'   removed; when values conflict, both versions are retained with a '.meta'
#'   suffix added to the metadata version.
#' @return A `move2` object containing the event data.
#' @examples
#' shags_csv <- system.file("/extdata/shags_example.csv",
#'   package = "tidytracks"
#' )
#' shags_tt <- tt_read_data(shags_csv,
#'   col_track_id = "bird_id",
#'   col_coords = c("lon", "lat"),
#'   col_date_time = "date_time"
#' )
#' shags_tt
#' @export

tt_read_data <- function(
  events,
  col_track_id,
  col_coords,
  col_date_time,
  format_date_time = NULL,
  crs = 4326,
  time_zone = "UTC",
  convert_meta = TRUE,
  meta = NULL
) {
  # if events is a character string (i.e. a file path), read it as a data frame
  if (inherits(events, "character")) {
    events <- utils::read.csv(events, stringsAsFactors = FALSE)
  }

  # Ensure events is a data frame
  if (!inherits(events, "data.frame")) {
    stop("events must be a data frame or a path to a csv file.")
  }

  # Check if the required columns are present
  if (!col_track_id %in% names(events)) {
    stop(paste("Column", col_track_id, "not found in the events data."))
  } else {
    # keep the original ids, to match them with those in the metadata
    track_ids <- events[[col_track_id]]
    # Ensure col_track_id is a factor, without levels that have no events
    # (e.g. if events is a subset of a larger data frame), which are not tracks
    events[[col_track_id]] <- droplevels(as.factor(track_ids))
  }
  if (!all(col_coords %in% names(events))) {
    stop(paste(
      "Columns",
      paste(col_coords, collapse = ", "),
      "not found in the events data."
    ))
  }
  # check that the col_date_time exists
  if (length(col_date_time) == 1 && !col_date_time %in% names(events)) {
    stop(paste("Column", col_date_time, "not found in the events data."))
  } else if (
    length(col_date_time) == 2 &&
      (!col_date_time[1] %in% names(events) ||
         !col_date_time[2] %in% names(events))
  ) {
    stop(paste(
      "Columns",
      paste(col_date_time, collapse = ", "),
      "not found in the events data."
    ))
  }

  # check that col_date_time is either a single character or a vector of two
  # characters
  if (
    !is.character(col_date_time) ||
      length(col_date_time) < 1 ||
      length(col_date_time) > 2
  ) {
    stop("col_date_time must be a character vector of length 1 or 2.")
  }

  # make sure there are no pre-existing NAs in any of the required columns
  # i.e. col_track_id, col_coords, col_date_time
  required_cols <- c(col_track_id, col_coords, col_date_time)
  for (col in required_cols) {
    if (any(is.na(events[[col]]))) {
      stop(paste(
        "Column",
        col,
        paste0(
          "contains missing values (NAs). Please remove or impute these ",
          "before proceeding."
        )
      ))
    }
  }

  # combine date/time columns if necessary before converting to POSIXct
  if (length(col_date_time) == 1) {
    # already a single date_time column
    date_time_raw <- events[[col_date_time]]
    # Store original name(s) for error messages.
    col_date_time_original <- col_date_time
  } else {
    # combine separate date + time columns into one string, separated by a space
    date_time_raw <- paste(
      events[[col_date_time[1]]],
      events[[col_date_time[2]]]
    )

    # remove the old date/time columns
    events <- events %>%
      dplyr::select(-dplyr::all_of(col_date_time))

    # update col_date_time to the new column name
    # Store original name(s) for error messages.
    col_date_time_original <- col_date_time
    # Name the combined date-time field.
    col_date_time <- "date_time"
  }

  # Attempt to parse date-time with as.POSIXct, wrapped in tryCatch.
  # block to provide informative error messages
  if (is.factor(date_time_raw)) {
    date_time_raw <- as.character(date_time_raw)
  }
  events[[col_date_time]] <- tryCatch(
    {
      if (!is.null(format_date_time)) {
        # use the provided format
        # NB. if the provided format is wrong, you'll silently get NAs here
        as.POSIXct(date_time_raw, format = format_date_time, tz = time_zone)
      } else if (is.character(date_time_raw)) {
        # try a set of common formats
        format_auto <- guess_date_time_format(date_time_raw)
        if (is.null(format_auto)) {
          stop("no common date-time format matches all values")
        }
        as.POSIXct(trimws(date_time_raw), format = format_auto, tz = time_zone)
      } else {
        # already a date-time (e.g. POSIXct) or a date
        as.POSIXct(date_time_raw, tz = time_zone)
      }
    },
    error = function(e) {
      stop(
        "Failed to parse date-time field(s) '",
        paste(col_date_time_original, collapse = "', '"),
        "'.\nPlease check that the format is consistent and uses a ",
        "standard format (e.g. YYYY-mm-dd hh:mm:ss).\n",
        "You can specify a format with the format_date_time parameter.",
        call. = FALSE
      )
    }
  )

  # Check parsed date-time values for NAs, which indicate parsing failures.
  # Get the first two failing original character strings for the error message.
  idx_na <- which(is.na(events[[col_date_time]]))
  if (length(idx_na) > 0) {
    examples <- date_time_raw[utils::head(idx_na, 2)]
    # Adjust error message based on whether format_date_time was supplied or not
    if (!is.null(format_date_time)) {
      stop(
        "Some date-time values could not be parsed using ",
        "the provided format_date_time '",
        format_date_time,
        "'.\n",
        "Examples of unparsed date-time values: '",
        paste(examples, collapse = "', '"),
        "'.\nPlease check that the format_date_time parameter is correct ",
        "and the data are consistently formatted.",
        call. = FALSE
      )
    } else {
      stop(
        "Some date-time values could not be parsed using auto-detected ",
        "format.\n",
        "Examples of unparsed date-time values: '",
        paste(examples, collapse = "', '"),
        "'.\nPlease check that the date-time columns are consistently ",
        "formatted, or specify format_date_time.",
        call. = FALSE
      )
    }
  }

  # Create a move2 object
  move2_obj <- move2::mt_as_move2(
    sf::st_as_sf(events, coords = col_coords, crs = crs),
    time_column = col_date_time,
    track_id_column = col_track_id
  )

  # Convert track-specific attributes to meta data if requested
  if (convert_meta) {
    # Identify columns that may contain track-specific information.
    candidate_cols <- setdiff(
      names(events),
      c(col_track_id, col_coords, col_date_time)
    )
    to_move_cols <- c()
    if (length(candidate_cols) > 0) {
      # Check if these columns are unique within each track
      for (col in candidate_cols) {
        # Check if the column is unique within each level of the track id column
        is_unique <- all(tapply(
          events[[col]],
          events[[col_track_id]],
          function(x) length(unique(x)) == 1
        ))
        if (is_unique) {
          # if unique within each track, add to list to move to meta
          to_move_cols <- c(to_move_cols, col)
        }
      }
      if (length(to_move_cols) > 0) {
        move2_obj <- move2::mt_as_track_attribute(
          move2_obj,
          dplyr::any_of(to_move_cols)
        )
      }
    }
  }

  # If meta is provided, read and merge meta data
  if (!is.null(meta)) {
    # if meta is a character string (i.e. filepath), read it as a data frame
    if (inherits(meta, "character")) {
      meta <- utils::read.csv(meta, stringsAsFactors = FALSE)
    } # if it was already a dataframe, keep it as a dataframe

    # Ensure meta is a data frame
    if (!inherits(meta, "data.frame")) {
      stop("meta must be either NULL, a data frame or a path to a csv file.")
    }

    # check meta has the track ID field
    if (!col_track_id %in% names(meta)) {
      stop(paste("Column", col_track_id, "not found in the meta data."))
    }

    # join new meta to old meta
    old_meta <- show_meta(move2_obj)
    # the track ids are a factor in the events; convert the ids in the
    # metadata to the same factor, as their types often differ (e.g. integer
    # ids read from a csv file) and they cannot be joined otherwise. The ids
    # are matched by value with the original ids of the events, rather than as
    # strings, as as.character() can write the same number differently (e.g.
    # "1e+05" for 100000 as a double, but "100000" as an integer)
    meta[[col_track_id]] <- events[[col_track_id]][
      match(meta[[col_track_id]], track_ids)
    ]
    updated_meta <- dplyr::left_join(
      old_meta,
      meta,
      by = col_track_id,
      suffix = c("", ".meta")
    )
    # Remove duplicate `.meta` columns that match their base columns.
    for (col in names(updated_meta)) {
      if (grepl("\\.meta$", col)) {
        base_col <- sub("\\.meta$", "", col)
        if (base_col %in% names(updated_meta)) {
          # compare the two columns (including NA patterns), after casting
          # them to a common type, as the same values can be stored with
          # different types (e.g. integer and double, or character and
          # factor); columns with incompatible types (e.g. character and
          # numeric) conflict
          same_values <- tryCatch(
            all(vctrs::vec_equal(
              updated_meta[[base_col]],
              updated_meta[[col]],
              na_equal = TRUE
            )),
            vctrs_error_incompatible_type = function(e) FALSE
          )
          if (same_values) {
            # if identical, remove the .meta column
            updated_meta[[col]] <- NULL
          } else {
            # throw a warning that there will be a .meta column as the values
            # are conflicting between the two versions of the variable
            warning(paste0(
              "Conflicting values found for variable '",
              base_col,
              "' between events and metadata. ",
              "Keeping both versions with '.meta' suffix for metadata."
            ))
          }
        }
      }
    }
    # update the move2 object with the new meta data (which checks that the
    # metadata has a single row per track)
    show_meta(move2_obj) <- updated_meta
  }

  return(move2_obj)
}

# Date-time formats tried by tt_read_data() when no format is given, in order,
# each with a regular expression that the date part has to match. The pattern
# fixes the number of digits of the year, as strptime() also accepts 2-digit
# years for "%Y" (e.g. "15/01/24" would be read as 24 January of year 15 with
# "%Y/%m/%d"). NB. "%OS" accounts for fractional seconds but doesn't require
# them.
tt_date_time_formats <- data.frame(
  format = c(
    # --- ISO Formats (Unambiguous) ---
    "%Y-%m-%d %H:%M:%OS", # 2024-01-15 13:45:30.123
    "%Y/%m/%d %H:%M:%OS", # 2024/01/15 13:45:30.123
    "%Y-%m-%d %H:%M", # 2024-01-15 13:45
    "%Y/%m/%d %H:%M", # 2024/01/15 13:45

    # --- 4-Digit Year: DMY (International) ---
    "%d/%m/%Y %H:%M:%OS", # 15/01/2024 13:45:30.123
    "%d-%m-%Y %H:%M:%OS", # 15-01-2024 13:45:30.123
    "%d/%m/%Y %H:%M", # 15/01/2024 13:45
    "%d-%m-%Y %H:%M", # 15-01-2024 13:45

    # --- 4-Digit Year: MDY (American) ---
    "%m/%d/%Y %H:%M:%OS", # 01/15/2024 13:45:30.123
    "%m-%d-%Y %H:%M:%OS", # 01-15-2024 13:45:30.123
    "%m/%d/%Y %H:%M", # 01/15/2024 13:45
    "%m-%d-%Y %H:%M", # 01-15-2024 13:45

    # --- 2-Digit Year: DMY (International) ---
    "%d/%m/%y %H:%M:%OS", # 15/01/24 13:45:30.123
    "%d-%m-%y %H:%M:%OS", # 15-01-24 13:45:30.123
    "%d/%m/%y %H:%M", # 15/01/24 13:45
    "%d-%m-%y %H:%M", # 15-01-24 13:45

    # --- 2-Digit Year: MDY (American) ---
    "%m/%d/%y %H:%M:%OS", # 01/15/24 13:45:30.123
    "%m-%d-%y %H:%M:%OS", # 01-15-24 13:45:30.123
    "%m/%d/%y %H:%M", # 01/15/24 13:45
    "%m-%d-%y %H:%M" # 01-15-24 13:45
  ),
  date_regex = paste0(
    c(
      # ISO
      "^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}",
      "^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}",
      "^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}",
      "^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2}",
      # 4-Digit DMY
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}",
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}",
      # 4-Digit MDY
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}",
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{4}",
      # 2-Digit DMY
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}",
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}",
      # 2-Digit MDY
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}",
      "^[0-9]{1,2}/[0-9]{1,2}/[0-9]{2}",
      "^[0-9]{1,2}-[0-9]{1,2}-[0-9]{2}"
    ),
    "[[:space:]]"
  )
)

#' Guess the format of date-time strings
#'
#' Returns the first of the common formats in `tt_date_time_formats` whose
#' date pattern matches all the (non-missing) values in `x` and which parses
#' all of them. As strptime() ignores trailing characters, a format without
#' seconds would also parse times with seconds, dropping them (e.g. if only
#' some of the values have seconds), so such formats are only used if none of
#' the values has seconds.
#'
#' @param x A character vector of date-times.
#' @returns The format as a string, or `NULL` if no format matches.
#' @keywords internal
#' @noRd
guess_date_time_format <- function(x) {
  x <- trimws(x[!is.na(x)])
  has_seconds <- any(grepl("[0-9]:[0-9]{1,2}:[0-9]", x))
  for (i in seq_len(nrow(tt_date_time_formats))) {
    format <- tt_date_time_formats$format[i]
    if (
      (!has_seconds || grepl("%OS", format, fixed = TRUE)) &&
        all(grepl(tt_date_time_formats$date_regex[i], x)) &&
        !anyNA(strptime(x, format, tz = "UTC"))
    ) {
      return(format)
    }
  }
  NULL
}
