#' Group the events by variables from the metadata
#'
#' This function groups the events of a `move2` object by one or more variables
#' of the track metadata (e.g. the sex of each animal), for example to estimate
#' a home range for each group with the `hr_tt_*()` functions, which return the
#' grouping variables as columns. It is the counterpart of [filter_by_meta()]
#' for [dplyr::group_by()], and it replaces `move2::group_by_track_data()`, so
#' that it also works with locations in the metadata.
#'
#' To group the events, the grouping variables are moved from the metadata to
#' the events (as [as_event_column()] does), so that the only column in both
#' tables is the track id. They stay in the events after [dplyr::ungroup()],
#' and can be moved back with [as_meta_column()]; to group again by variables
#' that are already in the events, use [dplyr::group_by()]. A column of the
#' events with the name of a grouping variable is kept if it has the same
#' values as in the metadata (e.g. moved there by [as_event_column()] with
#' `.keep = TRUE`); otherwise, an error is raised.
#'
#' The grouping variables are evaluated on the metadata, so they can also be
#' new variables computed from its columns (e.g. `north = nest_lat > 0`), as in
#' [dplyr::group_by()]; the columns used to compute them stay in the metadata.
#'
#' Locations in the metadata (e.g. of a colony), stored as `sfc` columns (see
#' [sf_point_col()]), can be grouping variables, and are moved to the events as
#' `sfc` columns; the events keep their own geometry. An `sf` table of metadata
#' is turned into a plain table first, with its geometry kept as an `sfc`
#' column, which is renamed if it has the name of the geometry column of the
#' events (see [show_meta()]).
#'
#' @param .data A move2 object
#' @param ... Variables of the track metadata to group by, or new variables
#'   computed from them (as in [dplyr::group_by()])
#' @param .add When `FALSE` (the default), the new groups replace any existing
#'   groups; when `TRUE`, they are added to them (as in [dplyr::group_by()])
#' @param .drop Whether to drop the groups formed by levels of factors that do
#'   not appear in the data (as in [dplyr::group_by()])
#' @returns A grouped move2 object, with the grouping variables moved from the
#'   metadata to the events
#' @seealso [filter_by_meta()] to filter the tracks by variables of the
#'   metadata, and [as_event_column()] and [as_meta_column()] to move variables
#'   between the metadata and the events.
#' @export
#' @examples
#' # group the events by the sex of each animal
#' sex_tt <- example_tt %>% group_by_meta(sex)
#' dplyr::group_keys(sex_tt)
#' # sex has been moved from the metadata to the events
#' show_meta(sex_tt)
#'
#' # group by a new variable computed from the metadata
#' example_tt %>%
#'   group_by_meta(nest_north = nest_lat > 0) %>%
#'   dplyr::group_keys()
#'
#' # group by the locations of the nests, stored as an sfc column of the
#' # metadata
#' nests_tt <- example_tt
#' show_meta(nests_tt)$nest <- sf_point_col(
#'   x = show_meta(nests_tt)$nest_lon,
#'   y = show_meta(nests_tt)$nest_lat,
#'   crs = 4326
#' )
#' nests_tt %>%
#'   group_by_meta(nest) %>%
#'   dplyr::group_keys()
group_by_meta <- function(.data, ..., .add = FALSE,
                          .drop = dplyr::group_by_drop_default(.data)) {
  # move2 cannot join an sf table of metadata to the events, so it is turned
  # into a plain table, with its geometry kept as an sfc column (renamed if it
  # has the name of the geometry column of the events)
  .data <- with_plain_meta(.data) # nolint: object_usage_linter.
  meta <- show_meta(.data)
  track_id_col <- move2::mt_track_id_column(.data)
  dots <- rlang::enquos(...)
  # variables given by name that are not in the metadata, but in the events
  # (e.g. moved there by an earlier call of group_by_meta()), are to be
  # grouped with the group_by() of dplyr
  given_by_name <- vapply(dots, rlang::quo_is_symbol, logical(1))
  names_given <- vapply(dots[given_by_name], rlang::as_name, character(1))
  in_events_only <- intersect(setdiff(names_given, names(meta)), names(.data))
  if (length(in_events_only) > 0) {
    stop(
      "Column(s) ", paste0("'", in_events_only, "'", collapse = ", "),
      " are not in the metadata, but in the events (e.g. moved there by an ",
      "earlier call of group_by_meta()); group by them with ",
      "dplyr::group_by() (with `.add = TRUE` to add them to other groups)",
      call. = FALSE
    )
  }
  # evaluate the grouping variables on the metadata, as dplyr::group_by() does,
  # so that they can be columns of the metadata or new variables computed
  # from them
  meta_grouped <- dplyr::group_by(meta, !!!dots)
  group_cols <- dplyr::group_vars(meta_grouped)
  # store the grouping variables (including the new ones) in the metadata,
  # keeping the class of the metadata table
  meta[group_cols] <- dplyr::ungroup(meta_grouped)[group_cols]
  # the track id is in both tables already; the other grouping variables are
  # moved to the events
  to_move <- setdiff(group_cols, track_id_col)
  .data <- move2::mt_set_track_data(.data, meta)
  # move the other grouping variables from the metadata to the events; those
  # that are already columns of the events (e.g. the id of each animal before
  # tt_split_trips()) are kept in the events, if they have the same values as
  # in the metadata, and only removed from the metadata (otherwise, an error
  # is raised)
  if (length(to_move) > 0) {
    .data <- as_event_column(.data, dplyr::all_of(to_move))
  }
  # finally, group the events, as dplyr::group_by() does
  dplyr::group_by(
    .data,
    !!!rlang::syms(group_cols),
    .add = .add,
    .drop = .drop
  )
}
