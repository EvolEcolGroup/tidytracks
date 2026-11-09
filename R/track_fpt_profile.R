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
#' has no clear peak. The variance at large radii is based on few events, as
#' fewer circles are left in both directions (see column `n_valid`). Very small
#' radii, within a single step between locations, are not informative: the
#' crossing times are then interpolated between two locations, so the FPT just
#' reflects the speed of the step. The FPT also depends on the sampling
#' interval, so consider regularising the tracks (see [tt_regular_time()]) if
#' it is not constant.
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
#'   `as_units(seq(1, 50), "km")`. If `NULL` (the default), 50 radii are used,
#'   evenly spaced on a log scale between the median distance between
#'   consecutive locations and the diagonal of the bounding box of the largest
#'   track, in the units of the projection of `x`.
#' @returns A tibble of class `fpt_profile_tbl`, with one row per track (or
#'   group) and radius, and columns:
#' - the id of the track or group (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`), in the order of the
#'   tracks in the metadata if `x` is not grouped, or else in the order of
#'   [dplyr::group_keys()]
#' - `radius`: the radius, as a `units` column, in increasing order
#' - `var_log_fpt`: the variance of the log of the FPT (which does not depend
#'   on the units of the FPT); `NA` if fewer than two events have an FPT
#' - `n_valid`: the number of events with an FPT
#' @seealso [event_fpt()], [track_suggest_ars_scale()]
#' @export
#' @examples
#' x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
#' profile <- track_fpt_profile(x, radii = as_units(c(50, 100, 200), "km"))
#' profile
#' library(ggplot2)
#' autoplot(profile)
track_fpt_profile <- function(x, radii = NULL) {
  check_fpt_x(x)
  crs_units <- sf::st_crs(x)$ud_unit
  if (is.null(radii)) {
    radii_crs <- fpt_default_radii(x)
    radius <- units::set_units(radii_crs, crs_units, mode = "standard")
  } else {
    radii_crs <- fpt_radii_in_crs_units(radii, x)
    # the radii are returned in the units in which they were given
    radius <- units::set_units(
      units::set_units(radii_crs, crs_units, mode = "standard"),
      units(radii),
      mode = "standard"
    )
  }

  # the FPT is always computed within tracks; groups only pool the results
  fpt <- fpt_matrix(x, radii_crs)
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

  log_fpt <- log(fpt)
  # e.g. a time of 0, from locations with duplicated times on both sides
  log_fpt[!is.finite(log_fpt)] <- NA_real_
  stats_by_group <- lapply(seq_along(group_order), function(group) {
    fpt_variance(log_fpt[group_index == group, , drop = FALSE])
  })

  n_radii <- length(radii_crs)
  profile <- tibble::tibble(
    group_id = rep(group_labels, each = n_radii),
    radius = rep(radius, times = length(group_labels)),
    var_log_fpt = unlist(lapply(stats_by_group, `[[`, "variance")),
    n_valid = unlist(lapply(stats_by_group, `[[`, "n_valid"))
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

#' Default radii for the FPT
#'
#' @param x A move2 object, checked with `check_fpt_x()`.
#' @returns A numeric vector of 50 radii, in the units of the CRS of `x`.
#' @keywords internal
#' @noRd
fpt_default_radii <- function(x) {
  xy <- sf::st_coordinates(x)
  ids <- as.character(event_track_id(x))
  usable <- stats::complete.cases(xy) & !is_trip_na(ids)
  rows_by_track <- split(which(usable), ids[usable])
  steps <- unlist(lapply(rows_by_track, function(rows) {
    sqrt(diff(xy[rows, 1])^2 + diff(xy[rows, 2])^2)
  }))
  diagonals <- vapply(rows_by_track, function(rows) {
    sqrt(diff(range(xy[rows, 1]))^2 + diff(range(xy[rows, 2]))^2)
  }, numeric(1))
  smallest <- stats::median(steps[steps > 0])
  largest <- max(diagonals)
  if (!isTRUE(smallest > 0 && largest > smallest)) {
    stop("the default radii cannot be computed for x; set radii")
  }
  exp(seq(log(smallest), log(largest), length.out = 50))
}

#' Autoplot a profile of the variance of the first passage time
#'
#' Plots the variance of the log of the first passage time against the radius,
#' on a log scale, with one line per track (or group) and, if there is more than
#' one, their median at each radius.
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
    variance = object$var_log_fpt
  )
  to_plot <- to_plot[!is.na(to_plot$variance), ]
  p <- ggplot2::ggplot(
    to_plot,
    ggplot2::aes(x = .data$radius, y = .data$variance)
  )
  if (length(unique(to_plot$id)) > 1) {
    median_by_radius <- stats::aggregate(
      variance ~ radius,
      to_plot,
      stats::median
    )
    p <- p +
      ggplot2::geom_line(
        ggplot2::aes(group = .data$id),
        colour = "grey75",
        linewidth = 0.3
      ) +
      ggplot2::geom_line(data = median_by_radius, linewidth = 1)
  } else {
    p <- p + ggplot2::geom_line(linewidth = 1)
  }
  p +
    ggplot2::scale_x_log10() +
    ggplot2::labs(
      x = paste0("Radius (", radius_units, ")"),
      y = "Variance of log(FPT)"
    ) +
    ggplot2::theme_minimal()
}
