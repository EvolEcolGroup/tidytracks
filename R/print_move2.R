#' @export
print.move2 <- function(x, ..., n = getOption("sf_max_print", default = 10L)) {
  avg_dur <- mean( # nolint: object_usage_linter.
    do.call(
      c,
      lapply(
        lapply(
          split(move2::mt_time(x), move2::mt_track_id(x), drop = TRUE),
          range
        ),
        diff
      )
    )
  )
  cat(
    cli::format_message(
      paste0(
        "A {.cls move2} with `track_id_column` ",
        "{.val {move2::mt_track_id_column(x)}} and `time_column` ",
        "{.val {move2::mt_time_column(x)}}"
      )
    ),
    "\n",
    sep = ""
  )
  cat(
    cli::format_message(
      paste0(
        "Containing {mt_n_tracks(x)} track{?s} lasting {?on average} ",
        "{format(avg_dur, digits=3)} in a"
      )
    ),
    "\n",
    sep = ""
  )
  NextMethod(n = n)
  cat(cli::format_message("To see track metadata, use `show_meta()`"))
  invisible(x)
}
