#' Quantify the home range using local convex hulls (LoCoH)
#'
#' This function estimates the home range of an animal using the local convex
#' hull (LoCoH) method of Getz & Wilmers (2004) and Getz et al. (2007). A
#' convex hull is built around each location and a set of its neighbours; the
#' hulls are then sorted from the smallest to the largest, and the home range
#' for a given level is the union of the smallest hulls that, between them,
#' contain that proportion of the locations. Unlike the minimum convex polygon
#' ([hr_tt_mcp()]), LoCoH home ranges can have several parts, holes and
#' concave edges, so they can exclude areas that are never visited.
#'
#' @details Events with an empty geometry (i.e. no location) are ignored.
#'
#' Three ways of choosing the neighbours of each location are available,
#' depending on `type`:
#' - `"k"` (fixed number of neighbours): each hull is built from a location and
#'   its `n` nearest neighbours. Note that `adehabitatHR::LoCoH.k()` uses
#'   `k - 1` neighbours, so `n = k - 1` gives the same hulls.
#' - `"r"` (fixed radius): each hull is built from all the locations within a
#'   distance `n` of a location.
#' - `"a"` (adaptive): each hull is built from the locations closest to a
#'   location such that the sum of their distances to it is at most `n`. Getz
#'   et al. (2007) suggest using the largest distance between any two locations
#'   as a starting value for `n`.
#'
#' The neighbour search, the hulls, their areas and the number of hulls needed
#' for each level are computed in C++ (with a k-d tree for the neighbour
#' search); the union of the hulls is computed with [sf::st_union()].
#'
#' The rules follow `amt::hr_locoh()`: each
#' level is matched to the union of hulls whose coverage (the proportion of
#' locations in the hulls) is closest to it, so the actual coverage can be a
#' little above or below the requested level. A hull with no area (when all its
#' locations lie on a line, or are at the same place, as it may be the case
#' for locations at the den or nest) counts towards the
#' coverage, but only becomes part of the isopleth if `buffer` is positive.
#' `amt::hr_locoh()` buffers every hull by 1e-5 (its `rand_buffer`); setting
#' `buffer = 1e-5` here gives the same isopleths.
#'
#' Distances are computed in the units of the projection of `x`, and hulls are
#' built and merged on a plane. For unprojected data (longitude/latitude),
#' distances (and so `n` for types `"r"` and `"a"`, and `buffer`) are thus in
#' degrees, and the hulls are distorted (increasingly so away from the
#' equator); it is recommended to project `x` to an appropriate projection
#' before using this function. Areas are computed with [sf::st_area()], in the
#' units of the projection of `x` (e.g. m^2 for a UTM projection), or in m^2
#' for unprojected data.
#'
#' @param x A move2 object; if explicitly grouped, the home range is estimated
#'   for each group, combining all tracks within each group. Otherwise, the
#'   track id is used as grouping variable. Every group must have events, so
#'   groupings with empty groups (e.g. from grouping by a factor with unused
#'   levels with `.drop = FALSE`) give an error.
#' @param n The parameter of the LoCoH, whose meaning depends on `type`: the
#'   number of nearest neighbours for `"k"` (a whole number of at least 2), the
#'   radius for `"r"`, or the maximum sum of the distances for `"a"` (both in
#'   the units of the projection of `x`). Either a single value, or a vector
#'   with one value per group, matched to the groups in the order of
#'   [dplyr::group_keys()] (i.e. sorted by the grouping variables).
#' @param type The type of LoCoH: `"k"` (the default), `"r"` or `"a"` (see
#'   Details).
#' @param levels A vector of levels (proportions of locations) for the home
#'   ranges, as numbers between 0 and 1. The default is `c(0.5, 0.95)`, which
#'   corresponds to the 50% and 95% home ranges.
#' @param buffer A non-negative number: the distance (in the units of the
#'   projection of `x`) by which the home ranges are buffered. The default, 0,
#'   leaves them as they are; a small positive value (e.g. 1e-5, as in
#'   `amt::hr_locoh()`) also includes the hulls with no area (see Details).
#' @returns An `sf` tibble of subclass `hr_tt_poly_tbl` of results, with one
#' row per group and level (with the groups in the order of
#' [dplyr::group_keys()], i.e. sorted by the grouping variables), and columns:
#' - the grouping variable (as named in `x`; if `x` is grouped by
#'   multiple variables, this column is named `group_id`): the ids from the
#'   grouping of `x`
#' - `method`: the method used to estimate the home range (`"locoh"`)
#' - `type`: the type of LoCoH (`"k"`, `"r"` or `"a"`)
#' - `n`: the parameter of the LoCoH
#' - `level`: the level of the home range
#' - `area`: the area of the home range (as computed by `sf::st_area()`)
#' - `geometry`: the geometry of the home range as sf multipolygons
#' @references Getz, W. M., & Wilmers, C. C. (2004). A local nearest-neighbor
#'   convex-hull construction of home ranges and utilization distributions.
#'   Ecography, 27(4), 489-505.
#'
#'   Getz, W. M., Fortmann-Roe, S., Cross, P. C., Lyons, A. J., Ryan, S. J., &
#'   Wilmers, C. C. (2007). LoCoH: nonparameteric kernel methods for
#'   constructing home ranges and utilization distributions. PLoS ONE, 2(2),
#'   e207.
#' @export
#' @examples
#' # the tracks in example_tt are short (5 locations each), so each hull is
#' # built from a location and its 3 nearest neighbours
#' example_locoh <- hr_tt_locoh(example_tt, n = 3)
#' example_locoh
#' library(ggplot2)
#' ggplot(example_locoh) +
#'   geom_sf(aes(fill = track_id), alpha = 0.7)
hr_tt_locoh <- function(
  x,
  n = 10,
  type = c("k", "r", "a"),
  levels = c(0.5, 0.95),
  buffer = 0
) {
  type <- match.arg(type)
  # if x is not grouped, use the track ID column as grouping variable
  if (!inherits(x, "grouped_df")) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  # as in hr_tt_kde(), per-group values of n are matched to the groups by
  # their position in the group keys, which must therefore all be estimated
  check_no_empty_groups(x) # nolint: object_usage_linter.

  # Check if levels are valid
  if (
    !is.numeric(levels) ||
      length(levels) == 0 ||
      anyNA(levels) ||
      any(levels < 0 | levels > 1)
  ) {
    stop("levels must be between 0 and 1")
  }
  # reorder levels from big to small
  levels <- sort(levels, decreasing = TRUE)
  # check buffer
  if (
    !is.numeric(buffer) ||
      length(buffer) != 1 ||
      !is.finite(buffer) ||
      buffer < 0
  ) {
    stop("buffer must be a single non-negative number")
  }

  # get the group indices
  group_index <- dplyr::group_indices(x)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  # extract coordinates
  xy <- sf::st_coordinates(x)
  # events with an empty geometry have no location to contribute to the hulls
  located <- stats::complete.cases(xy)
  xy <- xy[located, , drop = FALSE]
  group_index <- group_index[located]
  # a hull needs at least 3 locations to have an area
  n_locations <- tabulate(group_index, nbins = length(group_labels))
  if (any(n_locations < 3)) {
    stop(
      "each group must contain at least 3 events with a location to compute ",
      "a LoCoH; groups with fewer locations: ",
      paste(group_labels[n_locations < 3], collapse = ", ")
    )
  }

  # check n, and recycle it to one value per group
  n <- check_locoh_n(n, type, n_locations, group_labels)

  # look up the CRS (and whether it is longitude/latitude) once: sf asks PROJ
  # for its parameters every time, which takes a few milliseconds, i.e. more
  # than the whole LoCoH of a short track
  crs <- sf::st_crs(x)
  longlat <- isTRUE(sf::st_is_longlat(crs))

  group_id <- NULL # hack to avoid it being flagged as global in checks
  # one result per group, in the order of the group keys (rather than in the
  # order in which the groups appear in x), as for the values of n; all
  # groups have locations
  locoh_results <- foreach::foreach(group_id = seq_along(group_labels)) %do% {
    # Filter the data for the current group
    xy_sub <- xy[group_index == group_id, , drop = FALSE]
    # take n for this group now: inside tibble() below, group_id refers to
    # the column created there, not to the index of the group
    n_val <- n[group_id]
    # Create the home range for each level (without a CRS, which is set
    # for all groups at once below)
    geometry <- locoh_one_group(
      xy_sub,
      n = n_val,
      type = type,
      levels = levels,
      buffer = buffer,
      longlat = longlat
    )

    # Create a tibble with the results (areas are computed below)
    tibble::tibble(
      group_id = group_labels[group_id],
      method = "locoh",
      type = type,
      n = n_val,
      level = levels,
      area = NA_real_,
      geometry = geometry
    )
  }

  # combine the groups in one go (combining them one at a time, as foreach's
  # .combine does, takes time quadratic in the number of groups), cast the
  # results to an sf object, and compute all the areas in one call
  locoh_results <- dplyr::bind_rows(locoh_results)
  locoh_results <- sf::st_as_sf(locoh_results, crs = crs)
  locoh_results$area <- sf::st_area(locoh_results)

  # if there was a single grouping variable, rename the group_id column
  if (length(dplyr::group_vars(x)) == 1) {
    locoh_results <- locoh_results %>%
      dplyr::rename_with(
        ~ dplyr::group_vars(x),
        dplyr::all_of("group_id")
      )
  }

  # add a method attribute
  attr(locoh_results, "hr_tt_method") <- "locoh"
  class(locoh_results) <- c("hr_tt_poly_tbl", class(locoh_results))

  # Return the results as a hr_tt_poly_tbl
  return(locoh_results)
}

#' Check the parameter of a LoCoH
#'
#' Internal function that checks the value(s) of `n` given to [hr_tt_locoh()],
#' and recycles a single value to all groups.
#'
#' @param n The value(s) of `n` given to [hr_tt_locoh()].
#' @param type The type of LoCoH.
#' @param n_locations The number of locations in each group.
#' @param group_labels The labels of the groups (for error messages).
#' @returns A numeric vector with one value of `n` per group.
#' @keywords internal
#' @noRd
check_locoh_n <- function(n, type, n_locations, group_labels) {
  if (!is.numeric(n) || !(length(n) %in% c(1, length(n_locations)))) {
    stop(
      "n must be a single number or a vector with one value per group"
    )
  }
  if (length(n) == 1) {
    n <- rep(n, length(n_locations))
  }
  if (any(!is.finite(n) | n <= 0)) {
    stop("n must contain finite, positive values")
  }
  if (type == "k") {
    # with fewer than 2 neighbours, all hulls would be segments with no area
    if (any(n != round(n) | n < 2)) {
      stop("for type \"k\", n must be a whole number of at least 2")
    }
    # each location needs n neighbours other than itself
    too_few <- n >= n_locations
    if (any(too_few)) {
      stop(
        "for type \"k\", each group must contain more locations than n; ",
        "groups with too few locations: ",
        paste(group_labels[too_few], collapse = ", ")
      )
    }
  }
  n
}

#' Create LoCoH home ranges at multiple levels for a given group
#'
#' This is the internal function that is called by `hr_tt_locoh` to create the
#' home ranges at multiple levels for a given group. It is not intended to be
#' called directly by the user.
#'
#' @param xy a matrix of coordinates
#' @param n the parameter of the LoCoH
#' @param type the type of LoCoH (`"k"`, `"r"` or `"a"`)
#' @param levels A vector of levels for the home ranges
#' @param buffer the distance by which to buffer the home ranges
#' @param longlat whether the coordinates are longitudes and latitudes
#' @returns An `sfc` of multipolygons (without a CRS), one per level (in the
#'   order of `levels`)
#' @keywords internal
#' @noRd
locoh_one_group <- function(xy, n, type, levels, buffer, longlat) {
  # The hulls are built on a plane (in degrees for unprojected data), so they
  # are also merged on a plane, by GEOS, without a CRS (with a CRS in
  # longitude/latitude, sf would use s2, on the sphere, instead).
  #
  # GEOS works in floating point and loses precision when the coordinates
  # are large compared with the details of the geometries (e.g. projected
  # coordinates in the millions and a buffer of 1e-5): it then falls back to
  # a coarser precision, which distorts the isopleths. So the hulls are built
  # relative to the centre of the locations, and the isopleths are shifted
  # back at the end.
  shift <- c(mean(range(xy[, 1])), mean(range(xy[, 2])))

  # the C++ code finds the neighbours, builds the hulls, sorts them by area,
  # and works out how many of the smallest hulls each level needs; it returns
  # those hulls as sf geometries, from the smallest to the largest
  hulls <- locoh_cpp( # nolint: object_usage_linter.
    xy[, 1],
    xy[, 2],
    type = type,
    n = n,
    levels = levels,
    buffer = buffer,
    shift_x = shift[1],
    shift_y = shift[2]
  )

  # Union the hulls for each level. The isopleths are nested (the isopleth
  # for a level is the union of the j smallest hulls, with j increasing with
  # the level), so rather than computing each union from scratch, we start
  # from the smallest isopleth and add the hulls needed by each larger one to
  # the union computed so far.
  geometry <- vector("list", length(levels))
  union_so_far <- NULL
  hulls_so_far <- 0
  for (i in order(hulls$n_hulls)) {
    n_hulls <- hulls$n_hulls[i]
    if (n_hulls > hulls_so_far) {
      new_hulls <- seq(hulls_so_far + 1, n_hulls)
      # without a buffer, hulls with no area (points and segments) add
      # nothing to the isopleth, so leave them out of the union
      if (buffer == 0) {
        new_hulls <- new_hulls[!hulls$degenerate[new_hulls]]
      }
      if (length(new_hulls) > 0) {
        # union the new hulls between them first (a cascaded union, which is
        # fast for many small polygons), then with the union so far; the
        # latter is also a union of a collection (rather than of two
        # geometries) because, with a buffer, the unions can contain points
        # and lines, which GEOS cannot overlay with polygons
        new_union <- sf::st_union(sf::st_sfc(hulls$hulls[new_hulls]))
        union_so_far <- if (is.null(union_so_far)) {
          new_union
        } else {
          sf::st_union(c(union_so_far, new_union))
        }
      }
      hulls_so_far <- n_hulls
    }
    # if all hulls so far have no area, the isopleth is empty
    geometry[[i]] <- if (is.null(union_so_far)) {
      sf::st_sfc(sf::st_multipolygon())
    } else {
      union_so_far
    }
  }
  geometry <- do.call(c, geometry)

  # buffering the union is the same as unioning the buffered hulls, but it is
  # much faster, as there is only one geometry to buffer
  if (buffer > 0) {
    geometry <- sf::st_buffer(geometry, buffer)
  }
  # GEOS can create vertices (where the edges of hulls cross) so close to
  # other vertices that s2, which sf uses for unprojected data (e.g. to
  # compute areas), sees them as the same vertex and rejects the polygon.
  # Simplifying with a tiny tolerance (1e-9 degrees, about 0.1 mm) removes
  # such vertices without changing the isopleths otherwise.
  if (longlat) {
    geometry <- sf::st_simplify(geometry, dTolerance = 1e-9)
  }
  # return multipolygons, as isopleths can have several parts, shifted back
  # to the original coordinates
  sf::st_cast(geometry, "MULTIPOLYGON") + shift
}
