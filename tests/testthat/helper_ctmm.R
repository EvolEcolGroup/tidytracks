# a small tibble of tracks from the buffalo dataset of ctmm (in its original
# projected coordinates), with the first n locations of some of the buffalo,
# to keep the fitting of the movement models fast
ctmm_example_tt <- function(n = 100, tracks = c("Cilla", "Gabs")) {
  buffalo <- NULL # to avoid a note on the global variable created by data()
  utils::data("buffalo", package = "ctmm", envir = environment())
  buffalo_tt <- move2::mt_as_move2(buffalo[tracks])
  # the first n events of each track
  first_events <- lapply(
    split(seq_len(nrow(buffalo_tt)), event_track_id(buffalo_tt)),
    utils::head,
    n = n
  )
  buffalo_tt[sort(unlist(first_events)), ]
}
