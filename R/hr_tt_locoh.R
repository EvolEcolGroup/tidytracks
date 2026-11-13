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
#' search). Without a buffer, the union of the hulls is also computed in C++,
#' taking advantage of the hulls being convex (with exact geometric
#' predicates, and the same formula as GEOS for the points where the edges of
#' two hulls cross), which is much faster than with GEOS; with a buffer, it is
#' computed with [sf::st_union()]. The union is also computed with
#' [sf::st_union()] where it would take longer in C++ (with hundreds of
#' neighbours per location), and in the rare cases where it cannot be
#' computed reliably in C++, or where rounding makes an isopleth from C++
#' invalid (unless the isopleth from [sf::st_union()] is invalid too).
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
#'   with one value per group, matched to the groups in the order in which
#'   they are returned: the order of the tracks in the metadata (see
#'   [show_meta()]) if `x` is not grouped, or else the order of
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
#' row per group and level (with the tracks in the order of the metadata if
#' `x` is not grouped, or else with the groups in the order of
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
  by_track <- !inherits(x, "grouped_df")
  if (by_track) {
    x <- dplyr::group_by(x, .data[[move2::mt_track_id_column(x)]])
  }
  # as in hr_tt_kde(), per-group values of n are matched to the groups by
  # their position in the order in which they are returned, so every group
  # listed in the group keys must be estimated
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

  # get the group indices, numbered in the order in which the groups are
  # returned (the order of the tracks in the metadata if x was not grouped,
  # or else the order of the group keys)
  group_order <- hr_group_order(x, by_track) # nolint: object_usage_linter.
  group_index <- match(dplyr::group_indices(x), group_order)
  group_labels <- tidyr::unite(dplyr::group_keys(x), col = "group_labels") %>%
    dplyr::pull(1)
  group_labels <- group_labels[group_order]
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

  # the rows of xy of each group (splitting them once is much faster, with
  # many groups, than finding the rows of each group among all the rows)
  group_rows <- split(
    seq_along(group_index),
    factor(group_index, levels = seq_along(group_labels))
  )

  group_id <- NULL # hack to avoid it being flagged as global in checks
  # one result per group, in the order in which they are returned (rather
  # than in the order in which the groups appear in x), as for the values of
  # n; all groups have locations
  geometry <- foreach::foreach(group_id = seq_along(group_labels)) %do% {
    # Create the home range for each level (without a CRS, which is set
    # for all groups at once below)
    locoh_one_group(
      xy[group_rows[[group_id]], , drop = FALSE],
      n = n[group_id],
      type = type,
      levels = levels,
      buffer = buffer,
      longlat = longlat
    )
  }

  # the isopleths of all groups, and their areas, computed in one call
  geometry <- sf::st_sfc(unlist(geometry, recursive = FALSE))
  area <- locoh_area(geometry, crs = crs, longlat = longlat)

  # create a tibble with the results of all groups in one go (creating a
  # tibble for each group and combining them takes much longer when there
  # are many groups), and cast it to an sf object. If there is a single
  # grouping variable, the column of the groups is named after it (renaming
  # it before casting to sf, rather than with dplyr::rename_with() after,
  # saves time on short tracks); otherwise it is named group_id. The columns
  # are computed before the tibble is created: tibble() evaluates each column
  # with the columns before it in scope, so a column of groups named, e.g.,
  # "levels" would otherwise be used instead of the levels.
  group_column <- if (length(dplyr::group_vars(x)) == 1) {
    dplyr::group_vars(x)
  } else {
    "group_id"
  }
  output_columns <- c("method", "type", "n", "level", "area", "geometry")
  if (group_column %in% output_columns) {
    stop(
      "the grouping variable (or the track id column) cannot be named ",
      "like a column of the result (",
      paste0("\"", output_columns, "\"", collapse = ", "),
      "); rename it first"
    )
  }
  group_values <- rep(group_labels, each = length(levels))
  n_values <- rep(n, each = length(levels))
  level_values <- rep(levels, times = length(group_labels))
  locoh_results <- tibble::tibble(
    group_id = group_values,
    method = "locoh",
    type = type,
    n = n_values,
    level = level_values,
    area = area,
    geometry = geometry
  )
  names(locoh_results)[1] <- group_column
  locoh_results <- sf::st_as_sf(locoh_results, crs = crs)

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

#' Areas of the LoCoH isopleths
#'
#' Internal function that computes the areas of the isopleths as
#' [sf::st_area()] does, but asks PROJ for the parameters of the CRS only
#' once (to get its units) rather than twice, which matters for short tracks:
#' for projected data, the areas are computed without the CRS, and given the
#' squared units of the CRS, as [sf::st_area()] does.
#'
#' @param geometry An `sfc` of the isopleths, without a CRS.
#' @param crs The CRS of the isopleths.
#' @param longlat Whether the CRS is longitude/latitude.
#' @returns The areas, as a `units` vector (or a numeric vector if the CRS
#'   has no units), as given by [sf::st_area()].
#' @keywords internal
#' @noRd
locoh_area <- function(geometry, crs, longlat) {
  unit <- if (longlat) NULL else crs$ud_unit
  if (is.null(unit)) {
    # longitude/latitude (areas on the sphere), or a CRS without units
    return(sf::st_area(sf::st_set_crs(geometry, crs)))
  }
  area <- sf::st_area(geometry)
  units(area) <- unit^2
  area
}

# The most work, per vertex of the hulls, that the union of the hulls in C++
# (convex_union.cpp) may take before it is left to GEOS. Its work grows with
# the number of hulls that overlap each hull times their number of vertices,
# which is small for the usual LoCoH (about 45 units per vertex for k = 10,
# and for tracks with a dense cluster of locations), but large with hundreds
# of neighbours (e.g. 200 for k = 500), or hulls with hundreds of vertices,
# when GEOS is faster. On an Intel i9-13900, the union in C++ takes 2-10 ns
# per unit of work, and GEOS 1-4 microseconds per vertex of the hulls: on
# tracks of 10,000 to 110,000 locations, with k from 10 to 1000 and a giving
# up to hundreds of vertices per hull, they took about as long with 175
# (k-LoCoH) to 750 (hulls of hundreds of vertices) units per vertex.
locoh_union_budget <- 250

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
#' @param cpp_union whether to merge the hulls in C++ when there is no buffer
#'   (`TRUE`, the default), or always with GEOS (`FALSE`, used by the tests to
#'   compare the two)
#' @param union_budget the most work, per vertex of the hulls, that the union
#'   in C++ may take, beyond which GEOS is faster (see `locoh_union_budget`)
#' @returns The multipolygons (without a CRS), one per level (in the order of
#'   `levels`), as an `sfc`
#' @keywords internal
#' @noRd
locoh_one_group <- function(xy, n, type, levels, buffer, longlat,
                            cpp_union = TRUE,
                            union_budget = locoh_union_budget) {
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
  # and works out how many of the smallest hulls each level needs. Without a
  # buffer, it also merges the hulls into the isopleths (much faster than
  # GEOS, as it can take advantage of the hulls being convex), and returns
  # them as MULTIPOLYGONs, in the original coordinates. Otherwise (or where
  # it cannot merge them reliably, or would take longer than GEOS), it
  # returns the hulls needed by the isopleths as sf geometries (in shifted
  # coordinates), from the smallest to the largest, to be merged by GEOS (in
  # locoh_union_geos()).
  locoh <- function(union_hulls) {
    locoh_cpp( # nolint: object_usage_linter.
      xy[, 1],
      xy[, 2],
      type = type,
      n = n,
      levels = levels,
      buffer = buffer,
      shift_x = shift[1],
      shift_y = shift[2],
      union_hulls = union_hulls,
      union_budget = union_budget
    )
  }
  union_hulls <- cpp_union && buffer == 0
  hulls <- locoh(union_hulls)
  if (is.null(hulls$isopleths)) {
    return(locoh_union_geos(hulls, levels, buffer, longlat, shift))
  }
  geometry <- sf::st_sfc(hulls$isopleths)
  if (longlat) {
    # see locoh_union_geos() for why isopleths in longitude/latitude are
    # simplified
    geometry <- sf::st_cast(
      sf::st_simplify(geometry, dTolerance = 1e-9),
      "MULTIPOLYGON"
    )
  }
  # The C++ code decides the topology of the isopleths exactly, but rounding
  # the coordinates of the points where the edges of the hulls cross can, in
  # rare cases, make an isopleth invalid (e.g. where two such points round to
  # nearly the same point). The hulls are then merged by GEOS, and its
  # isopleth for a level is used instead if it is valid (GEOS gives invalid
  # isopleths in other cases, and they can then also be wrong, whilst those
  # from C++ have the right area); checking their validity is fast.
  valid <- sf::st_is_valid(geometry) %in% TRUE
  if (!all(valid)) {
    geos <- locoh_union_geos(locoh(FALSE), levels, buffer, longlat, shift)
    use_geos <- !valid & sf::st_is_valid(geos) %in% TRUE
    geometry[use_geos] <- geos[use_geos]
  }
  geometry
}

#' Merge LoCoH hulls into isopleths with GEOS
#'
#' Internal function called by `locoh_one_group()`: the union of the hulls
#' needed by each isopleth, computed by GEOS (with a buffer, or if the union
#' could not be computed in C++).
#'
#' @param hulls the list returned by `locoh_cpp()` (with `union_hulls =
#'   FALSE`, or if the union could not be computed in C++).
#' @param levels A vector of levels for the home ranges
#' @param buffer the distance by which to buffer the home ranges
#' @param longlat whether the coordinates are longitudes and latitudes
#' @param shift the shift of the coordinates of the hulls, to be added back
#' @returns The multipolygons (without a CRS), one per level (in the order of
#'   `levels`), as an `sfc`
#' @keywords internal
#' @noRd
locoh_union_geos <- function(hulls, levels, buffer, longlat, shift) {
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
