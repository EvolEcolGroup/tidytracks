#' Compute how the variance of the first passage time changes with the radius
#'
#' This function computes the first passage time (FPT, see [event_fpt()]) of the
#' events of each track for a set of radii, and the variance of the log of the
#' FPT at each radius. The radius at which this variance peaks is the spatial
#' scale at which the animal concentrates its search, if it uses area-restricted
#' search (ARS) (Fauchald & Tveraa 2003): circles of that size can enclose a
#' patch where the animal stays, or a stretch where it travels fast, so their
#' FPT differs the most. It can be used to inform the choice of the bandwidth of
#' [hr_tt_kde()]; see [track_suggest_ars_scale()].
#'
#' The profile is best inspected (with [ggplot2::autoplot()]) before using any
#' scale derived from it. Not all species use ARS, in which case the variance
#' has no clear peak. The FPT also depends on the sampling interval, so
#' consider regularising the tracks (see [tt_regular_time()]) if it is not
#' constant.
#'
#' Not all radii are informative, which is why the default radii are chosen
#' for each track (or group) separately:
#' - Radii within a single step between locations: if a circle is smaller than
#'   both the steps before and after a location, its crossings are interpolated
#'   on these steps, so the FPT is the radius divided by the speed of the steps,
#'   and the variance of its log reflects the variation in speed, whatever the
#'   radius. The default radii start at twice the median distance between
#'   consecutive locations (ignoring locations that do not move).
#' - Large radii: an event has an FPT only if the track goes farther than the
#'   radius from it both before and after it, so as the radius grows, fewer
#'   events have an FPT (see column `n_valid`), and those that do are the
#'   events far from the ends of the track. Few events have an FPT for radii
#'   larger than half the extent of a track. The default radii end at half the
#'   diagonal of the bounding box of the track (of the largest track, for a
#'   group). Where the number of events with an FPT falls steeply, the
#'   variance can jump, so a radius is only used (column `enough_events`, see
#'   `min_prop_valid`) if at least half of the events of the track (or group)
#'   have an FPT at it.
#' - Radii suited to one track can be unsuited to another (e.g. tracks with
#'   different sampling intervals, or an animal that left the study area), so
#'   each track or group gets its own default radii.
#'
#' As the FPT only depends on the events of a track, and [tt_split_trips()]
#' makes each trip a track, the FPT of central place foragers split into trips
#' does not run across trips. Otherwise, circles that include the centre would
#' have a long FPT due to the time between trips, which can produce a peak in
#' the variance at about the distance of the foraging areas from the centre. To
#' obtain a profile per animal, rather than per trip, group `x` by a column with
#' the original track id: the FPT is still computed within each trip, and the
#' log FPTs of the trips of each animal are pooled to compute the variance.
#'
#' @references Fauchald, P. & Tveraa, T. (2003) Using first-passage time in the
#'   analysis of area-restricted search and habitat selection. Ecology, 84,
#'   282-288.
#'
#'   Pinaud, D. (2008) Quantifying search effort of moving animals at several
#'   spatial scales using first-passage time analysis: effect of the structure
#'   of environment and tracking systems. Journal of Applied Ecology, 45, 91-99.
#' @param x A move2 object in a projected coordinate reference system, ordered
#'   by time within each track; if explicitly grouped, one profile is computed
#'   for each group, pooling the log FPT of its tracks. Otherwise, one profile
#'   is computed for each track.
#' @param radii The radii, as a `units` object, e.g.
#'   `as_units(seq(1, 50), "km")`, used for all the tracks (or groups). If
#'   `NULL` (the default), each track (or group) gets 50 radii, evenly spaced on
#'   a log scale between twice the median distance between its consecutive
#'   locations and half the diagonal of the bounding box of its largest track,
#'   in the units of the projection of `x` (see Details). Tracks (or groups)
#'   for which these radii cannot be computed (e.g. with fewer than three
#'   locations) get a single row with missing values, and a warning.
#' @param min_prop_valid The smallest proportion of the events of a track (or
#'   group) that must have an FPT at a radius for its variance to be used by
#'   [track_suggest_ars_scale()] and drawn as solid by [ggplot2::autoplot()]
#'   (column `enough_events`). The default is 0.5. Events without a location,
#'   or in the dummy trips of [tt_split_trips()], are not counted.
#' @returns A tibble of class `fpt_profile_tbl`, with one row per track (or
#'   group) and radius, and columns:
#' - the id of the track or group (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`), in the order of the
#'   tracks in the metadata if `x` is not grouped, or else in the order of
#'   [dplyr::group_keys()]
#' - `radius`: the radius, as a `units` column, in increasing order within each
#'   track (or group), in the units of `radii` (or of the projection of `x`,
#'   for the default radii)
#' - `var_log_fpt`: the variance of the log of the FPT (which does not depend
#'   on the units of the FPT); `NA` if fewer than two events have an FPT
#' - `n_valid`: the number of events with an FPT
#' - `enough_events`: whether at least `min_prop_valid` of the events of the
#'   track (or group), and at least two, have an FPT
#' @seealso [event_fpt()], [track_suggest_ars_scale()]
#' @export
#' @examples
#' x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
#' profile <- track_fpt_profile(x, radii = as_units(c(50, 100, 200), "km"))
#' profile
#' library(ggplot2)
#' autoplot(profile)
track_fpt_profile <- function(x, radii = NULL, min_prop_valid = 0.5) {
  check_fpt_x(x)
  if (
    !is.numeric(min_prop_valid) ||
      length(min_prop_valid) != 1 ||
      !is.finite(min_prop_valid) ||
      min_prop_valid <= 0 ||
      min_prop_valid > 1
  ) {
    stop("min_prop_valid must be a single number between 0 (excluded) and 1")
  }
  crs_units <- sf::st_crs(x)$ud_unit
  if (!is.null(radii)) {
    # the same radii for all the groups, returned in the units in which they
    # were given
    radii_crs <- fpt_radii_in_crs_units(radii, x)
    radius_units <- units(radii)
  } else {
    radius_units <- crs_units
  }
  events <- fpt_events(x)

  # the FPT is always computed within tracks; groups only pool the results
  by_track <- !inherits(x, "grouped_df")
  if (by_track) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  check_no_empty_groups(x) # nolint: object_usage_linter.
  group_order <- hr_group_order(x, by_track) # nolint: object_usage_linter.
  group_index <- match(dplyr::group_indices(x), group_order)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  group_labels <- group_labels[group_order]

  # the rows of each group, found in a single pass: comparing all the rows
  # with each group in turn takes time proportional to the number of groups
  # times the number of events, e.g. with the many trips of tt_split_trips()
  rows_by_group <- unname(split(
    seq_along(group_index),
    factor(group_index, levels = seq_along(group_order))
  ))
  stats_by_group <- lapply(rows_by_group, function(rows) {
    group_radii <- if (is.null(radii)) {
      fpt_default_radii(events, rows)
    } else {
      radii_crs
    }
    if (is.null(group_radii)) {
      # no radii: a single row with missing values
      return(list(
        radii = NA_real_,
        variance = NA_real_,
        n_valid = 0,
        enough_events = FALSE
      ))
    }
    log_fpt <- log(fpt_matrix_of_rows(events, rows, group_radii))
    # e.g. a time of 0, from locations with duplicated times on both sides
    log_fpt[!is.finite(log_fpt)] <- NA_real_
    stats <- fpt_variance(log_fpt)
    # radii at which enough of the events of the group have an FPT
    min_valid <- max(2, min_prop_valid * sum(events$usable[rows]))
    c(
      list(radii = group_radii),
      stats,
      list(enough_events = stats$n_valid >= min_valid)
    )
  })

  # groups with usable events, but without default radii
  no_radii <- vapply(stats_by_group, function(st) anyNA(st$radii), logical(1))
  has_usable <- vapply(
    rows_by_group,
    function(rows) any(events$usable[rows]),
    logical(1)
  )
  if (any(no_radii & has_usable)) {
    warning(
      "the default radii could not be computed for ",
      paste(group_labels[no_radii & has_usable], collapse = ", "),
      " (too few locations, or locations too close together); set radii",
      call. = FALSE
    )
  }

  radius <- units::set_units(
    unlist(lapply(stats_by_group, `[[`, "radii")),
    crs_units,
    mode = "standard"
  )
  profile <- tibble::tibble(
    group_id = rep(
      group_labels,
      times = vapply(stats_by_group, function(st) length(st$radii), integer(1))
    ),
    radius = units::set_units(radius, radius_units, mode = "standard"),
    var_log_fpt = unlist(lapply(stats_by_group, `[[`, "variance")),
    n_valid = unlist(lapply(stats_by_group, `[[`, "n_valid")),
    enough_events = unlist(lapply(stats_by_group, `[[`, "enough_events"))
  )
  if (length(dplyr::group_vars(x)) == 1) {
    names(profile)[1] <- dplyr::group_vars(x)
  }
  class(profile) <- c("fpt_profile_tbl", class(profile))
  profile
}

#' Variance of each column of a matrix, ignoring missing values
#'
#' @param m A numeric matrix.
#' @returns A list with `variance` (`NA` for columns with fewer than two values)
#'   and `n_valid` (the number of values of each column).
#' @keywords internal
#' @noRd
fpt_variance <- function(m) {
  n_valid <- colSums(!is.na(m))
  # the sum of the squared deviations from the mean of each column, without
  # the time taken by apply() for each radius and track
  sums <- colSums(m, na.rm = TRUE)
  sums_sq <- colSums(m^2, na.rm = TRUE)
  variance <- (sums_sq - sums^2 / n_valid) / (n_valid - 1)
  variance[n_valid < 2] <- NA_real_
  # rounding can give a very small negative variance for equal values
  list(variance = unname(pmax(variance, 0)), n_valid = unname(n_valid))
}

#' Default radii for the FPT of a track or group
#'
#' 50 radii, evenly spaced on a log scale between twice the median distance
#' between consecutive locations of the tracks (ignoring the steps of length 0)
#' and half the diagonal of the bounding box of the largest track (see the
#' details of [track_fpt_profile()]).
#'
#' @param events A list, as returned by `fpt_events()`.
#' @param rows The rows of the events of the track or group.
#' @returns A numeric vector of 50 radii, in the units of the coordinates, or
#'   `NULL` if they cannot be computed (e.g. fewer than three locations, or all
#'   at the same place).
#' @keywords internal
#' @noRd
fpt_default_radii <- function(events, rows) {
  xy <- events$xy
  # the usable events of each track of the group
  usable_rows <- rows[events$usable[rows]]
  rows_by_track <- split(usable_rows, events$ids[usable_rows])
  steps <- unlist(lapply(rows_by_track, function(track_rows) {
    sqrt(diff(xy[track_rows, 1])^2 + diff(xy[track_rows, 2])^2)
  }))
  half_diagonals <- vapply(
    rows_by_track,
    function(track_rows) {
      sqrt(
        diff(range(xy[track_rows, 1]))^2 + diff(range(xy[track_rows, 2]))^2
      ) /
        2
    },
    numeric(1)
  )
  smallest <- 2 * stats::median(steps[steps > 0])
  largest <- max(half_diagonals, 0)
  if (!isTRUE(smallest > 0 && largest > smallest)) {
    return(NULL)
  }
  exp(seq(log(smallest), log(largest), length.out = 50))
}

#' Autoplot a profile of the variance of the first passage time
#'
#' Plots the variance of the log of the first passage time against the radius,
#' on a log scale, with one line per track (or group) and, if there is more than
#' one and they share the same radii (e.g. set with the argument `radii` of
#' [track_fpt_profile()]), their median at each radius. Radii at which too few
#' events have an FPT (column `enough_events`, see the argument
#' `min_prop_valid` of [track_fpt_profile()]) are drawn with a dashed line,
#' and left out of the median.
#'
#' @param object A tibble of class `fpt_profile_tbl`, as created with
#'   [track_fpt_profile()].
#' @param ... Not used.
#' @returns A `ggplot` object.
#' @importFrom ggplot2 autoplot
#' @export
#' @examples
#' x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
#' library(ggplot2)
#' autoplot(track_fpt_profile(x, radii = as_units(c(50, 100, 200), "km")))
autoplot.fpt_profile_tbl <- function(object, ...) {
  radius_units <- units::deparse_unit(object$radius)
  to_plot <- data.frame(
    id = as.character(object[[1]]),
    radius = as.numeric(object$radius),
    variance = object$var_log_fpt,
    enough = object$enough_events
  )
  to_plot <- to_plot[!is.na(to_plot$variance), ]
  # the variance at the radii with enough events, NA elsewhere, so that the
  # solid lines break at the other radii
  to_plot$solid <- ifelse(to_plot$enough, to_plot$variance, NA_real_)
  several <- length(unique(to_plot$id)) > 1
  p <- ggplot2::ggplot(
    to_plot,
    ggplot2::aes(x = .data$radius, group = .data$id)
  ) +
    # all the radii, dashed, under the radii with enough events
    ggplot2::geom_line(
      ggplot2::aes(y = .data$variance),
      colour = "grey70",
      linetype = "dashed",
      linewidth = 0.3
    ) +
    ggplot2::geom_line(
      ggplot2::aes(y = .data$solid),
      colour = if (several) "grey60" else "black",
      linewidth = if (several) 0.3 else 1,
      na.rm = TRUE
    )
  if (several) {
    # a median across groups only makes sense if they share their radii, which
    # the default radii, chosen for each group, do not
    radii_by_id <- split(as.numeric(object$radius), as.character(object[[1]]))
    shared <- all(vapply(
      radii_by_id,
      function(r) identical(r, radii_by_id[[1]]),
      logical(1)
    ))
    enough_to_plot <- to_plot[to_plot$enough, ]
    if (shared && nrow(enough_to_plot) > 0) {
      median_by_radius <- stats::aggregate(
        variance ~ radius,
        enough_to_plot,
        stats::median
      )
      p <- p +
        ggplot2::geom_line(
          data = median_by_radius,
          ggplot2::aes(x = .data$radius, y = .data$variance),
          inherit.aes = FALSE,
          linewidth = 1
        )
    }
  }
  p +
    ggplot2::scale_x_log10() +
    ggplot2::labs(
      x = paste0("Radius (", radius_units, ")"),
      y = "Variance of log(FPT)"
    ) +
    ggplot2::theme_minimal()
}
