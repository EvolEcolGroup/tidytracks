#' @export
print.move2 <- function(x, ..., n = getOption("sf_max_print", default = 10L)) {
  avg_dur <- mean(
    do.call(
      c,
      lapply(
        lapply(
          split(event_time(x),
            event_track_id(x),
            drop = TRUE
          ), range
        ),
        diff
      )
    )
  )
#  avg_dur <- lubridate::make_difftime(as.numeric(avg_dur, units = "secs"))
  cat(cli::format_message(
    "A {.cls move2} with `track_id_column` {.val {move2::mt_track_id_column(x)}} and `time_column` {.val {move2::mt_time_column(x)}}"
  ), "\n", sep = "")
  cat(cli::format_message("Containing {mt_n_tracks(x)} track{?s} lasting {?on average} {format(avg_dur, digits=3)} in a"), "\n", sep = "")
  NextMethod(n = n)
  cat(cli::format_message("To see track metadata, use `show_meta()`"))
  invisible(x)
}

