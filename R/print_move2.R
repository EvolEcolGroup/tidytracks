#' @export
print.move2 <- function(x, ..., n = getOption("sf_max_print", default = 10L)) {
  avg_dur <- mean(do.call(c, lapply(lapply(split(move2::mt_time(x), move2::mt_track_id(x), drop = TRUE), range), diff)))
  avg_dur <- lubridate::make_difftime(as.numeric(avg_dur, units = "secs"))
  cat(cli::format_message(
    "A {.cls move2} with `track_id_column` {.val {move2::mt_track_id_column(x)}} and `time_column` {.val {move2::mt_time_column(x)}}"
  ), "\n", sep = "")
  cat(cli::format_message("Containing {mt_n_tracks(x)} track{?s} lasting {?on average} {format(avg_dur, digits=3)} in a"), "\n", sep = "")
  NextMethod(n = n)
  message("To see track metadata, use `mt_show_meta()`")
  invisible(x)
}

#' Show the track metadata of a `move2` object
#'
#' @param x A move2 object
#' @return The metadata table from the input `move2` object
#' @export

mt_show_meta <- move2::mt_track_data

#' @keywords internal
mt_show_meta_old <- function(x, ..., n = getOption("sf_max_print", default = 10L)) {
  avg_dur <- mean(do.call(c, lapply(lapply(split(move2::mt_time(x), move2::mt_track_id(x), drop = TRUE), range), diff)))
  avg_dur <- lubridate::make_difftime(as.numeric(avg_dur, units = "secs"))
  cat(cli::format_message(
    "A {.cls move2} with `track_id_column` {.val {move2::mt_track_id_column(x)}} and `time_column` {.val {move2::mt_time_column(x)}}"
  ), "\n", sep = "")
  cat(cli::format_message("Containing {mt_n_tracks(x)} track{?s} lasting {?on average} {format(avg_dur, digits=3)} in a"), "\n", sep = "")
  # Print individual data
  track_meta <- move2::mt_track_data(x)
  if (n > 0L) {
    if (inherits(track_meta, "tbl_df")) {
      if (nrow(track_meta) > n) {
        cat(paste("Metadata for the first ", n, "tracks:\n"))
      } else {
        cat(paste("Track metadata:\n"))
      }
      print(track_meta, ..., n = n)
    } else {
      y <- track_meta
      if (nrow(y) > n) {
        cat(paste("Metadata for the first ", n, "tracks:\n"))
        y <- track_meta[1L:n, , drop = FALSE]
      } else {
        cat(paste("Track metadata:\n"))
      }
      print.data.frame(y, ...)
    }
  }
  invisible(x)
}
