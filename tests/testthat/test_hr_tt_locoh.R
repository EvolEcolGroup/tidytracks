# build a move2 object with a single track from a matrix of coordinates
make_locoh_tt <- function(xy, crs = 32630, id = "a") {
  coords <- data.frame(id = id, x = xy[, 1], y = xy[, 2])
  coords$time <- as.POSIXct("2024-01-01", tz = "UTC") +
    seq_len(nrow(coords)) * 60
  move2::mt_as_move2(
    sf::st_as_sf(coords, coords = c("x", "y"), crs = crs),
    time_column = "time",
    track_id_column = "id"
  )
}

# brute force neighbour sets, written as in amt::hr_locoh(), to check the
# k-d tree used in the C++ code
brute_neighbours <- function(xy, type, n) {
  lapply(seq_len(nrow(xy)), function(i) {
    d <- sqrt((xy[, 1] - xy[i, 1])^2 + (xy[, 2] - xy[i, 2])^2)
    if (type == "k") {
      # nearest neighbours other than the root, ties broken by index
      d[i] <- Inf
      c(i, order(d)[seq_len(n)])
    } else if (type == "r") {
      which(d <= n)
    } else {
      o <- order(d)
      o[cumsum(d[o]) <= n]
    }
  })
}

test_that("hr_tt_locoh works with multiple tracks", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_locoh <- hr_tt_locoh(boar_tt, n = 8)

  expect_s3_class(boar_locoh, "hr_tt_poly_tbl")
  expect_s3_class(boar_locoh, "sf")
  expect_equal(attr(boar_locoh, "hr_tt_method"), "locoh")
  expect_named(
    boar_locoh,
    c("name", "method", "type", "n", "level", "area", "geometry")
  )
  expect_equal(nrow(boar_locoh), 8)
  expect_equal(boar_locoh$method, rep("locoh", 8))
  expect_equal(boar_locoh$type, rep("k", 8))
  expect_equal(boar_locoh$n, rep(8, 8))
  expect_true(all(sf::st_geometry_type(boar_locoh) == "MULTIPOLYGON"))
  expect_equal(sf::st_crs(boar_locoh), sf::st_crs(boar_tt))

  # levels are sorted from the largest to the smallest within each track, and
  # larger levels have larger areas
  levels_by_track <- split(boar_locoh$level, boar_locoh$name)
  expect_true(all(vapply(
    levels_by_track,
    identical,
    logical(1),
    c(0.95, 0.5)
  )))
  areas_by_track <- split(as.numeric(boar_locoh$area), boar_locoh$name)
  expect_true(all(vapply(
    areas_by_track,
    function(area) area[1] > area[2] && area[2] > 0,
    logical(1)
  )))

  # LoCoH home ranges are within the MCP of all locations
  boar_mcp <- hr_tt_mcp(boar_tt, levels = 1)
  for (track in unique(boar_locoh$name)) {
    expect_true(sf::st_covers(
      sf::st_buffer(boar_mcp$geometry[boar_mcp$name == track], 1e-6),
      boar_locoh$geometry[boar_locoh$name == track][1],
      sparse = FALSE
    )[1, 1])
  }
})

test_that("hr_tt_locoh works with all types", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt <- boar_tt[boar_tt$name == "Brock", ]
  for (type in c("k", "r", "a")) {
    n <- switch(type, k = 10, r = 400, a = 3000)
    locoh <- hr_tt_locoh(boar_tt, n = n, type = type, levels = c(0.5, 0.9))
    expect_equal(locoh$type, rep(type, 2))
    expect_equal(locoh$level, c(0.9, 0.5))
    expect_true(all(as.numeric(locoh$area) > 0))
    expect_gt(as.numeric(locoh$area[1]), as.numeric(locoh$area[2]))
  }
})

test_that("hr_tt_locoh respects explicit grouping", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  grouped_locoh <- boar_tt |>
    dplyr::group_by(name) |>
    hr_tt_locoh(n = 8)
  default_locoh <- hr_tt_locoh(boar_tt, n = 8)

  expect_equal(grouped_locoh, default_locoh)

  # with several grouping variables, the groups are in a group_id column
  boar_tt$period <- rep(c("a", "b"), length.out = nrow(boar_tt))
  multi_locoh <- boar_tt |>
    dplyr::group_by(name, period) |>
    hr_tt_locoh(n = 5, levels = 0.9)
  expect_setequal(
    multi_locoh$group_id,
    paste(boar_tt$name, boar_tt$period, sep = "_")
  )
})

test_that("hr_tt_locoh accepts one n per group", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # groups are sorted by name: Brock, Calou, Chou, Jean
  n <- c(5, 6, 7, 8)
  locoh <- hr_tt_locoh(boar_tt, n = n, levels = 0.9)
  expect_equal(locoh$n, n)
  expect_equal(
    locoh[locoh$name == "Chou", ]$area,
    hr_tt_locoh(boar_tt[boar_tt$name == "Chou", ], n = 7, levels = 0.9)$area
  )
  expect_error(
    hr_tt_locoh(boar_tt, n = c(5, 6)),
    "n must be a single number or a vector with one value per group"
  )
})

test_that("hr_tt_locoh returns the groups in the order of the group keys", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # the groups are sorted in the reverse order of the tracks in the data:
  # Jean, Chou, Calou, Brock
  boar_tt$group <- factor(boar_tt$name, levels = rev(levels(boar_tt$name)))
  n <- c(5, 6, 7, 8)
  grouped_locoh <- hr_tt_locoh(
    dplyr::group_by(boar_tt, group),
    n = n,
    levels = 0.9
  )

  expect_equal(grouped_locoh$group, rev(levels(boar_tt$name)))
  expect_equal(grouped_locoh$n, n)
  expect_equal(
    grouped_locoh$area[grouped_locoh$group == "Jean"],
    hr_tt_locoh(boar_tt[boar_tt$name == "Jean", ], n = 5, levels = 0.9)$area
  )
})

test_that("hr_tt_locoh returns ungrouped tracks in metadata order", {
  # the events are in the order a, b, c, whilst the metadata is in the order
  # b, a, c
  x <- tt_order_time(
    readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  )
  n <- c(3, 4, 2)
  track_locoh <- hr_tt_locoh(x, n = n, levels = 0.9)

  expect_equal(track_locoh$track_id, c("b", "a", "c"))
  # per-track values of n are matched in the same order
  expect_equal(track_locoh$n, n)
  expect_equal(
    track_locoh$area[track_locoh$track_id == "b"],
    hr_tt_locoh(x[move2::mt_track_id(x) == "b", ], n = 3, levels = 0.9)$area
  )
})

test_that("hr_tt_locoh validates its arguments", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))

  expect_error(
    hr_tt_locoh(boar_tt, levels = -0.1),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_locoh(boar_tt, levels = 1.1),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_locoh(boar_tt, levels = NA),
    "levels must be between 0 and 1"
  )
  expect_error(hr_tt_locoh(boar_tt, type = "z"), "should be one of")
  expect_error(hr_tt_locoh(boar_tt, n = -1), "finite, positive")
  expect_error(hr_tt_locoh(boar_tt, n = "a"), "single number")
  expect_error(hr_tt_locoh(boar_tt, n = 2.5), "whole number of at least 2")
  expect_error(hr_tt_locoh(boar_tt, n = 1), "whole number of at least 2")
  # Calou has 19 locations
  expect_error(
    hr_tt_locoh(boar_tt, n = 19),
    "groups with too few locations: Calou"
  )
  expect_error(hr_tt_locoh(boar_tt, buffer = -1), "non-negative number")
  expect_error(hr_tt_locoh(boar_tt, buffer = c(1, 2)), "non-negative number")
})

test_that("hr_tt_locoh requires at least 3 locations per group", {
  set.seed(3)
  xy <- cbind(stats::rnorm(12), stats::rnorm(12))
  tracks <- make_locoh_tt(xy, id = c(rep("a", 10), "b", "b"))

  expect_error(
    hr_tt_locoh(tracks, n = 3),
    "at least 3 events with a location.*: b"
  )
})

test_that("hr_tt_locoh ignores events without a location", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt_empty <- boar_tt
  sf::st_geometry(boar_tt_empty)[5] <- sf::st_point()

  expect_equal(
    hr_tt_locoh(boar_tt_empty, n = 8),
    hr_tt_locoh(boar_tt[-5, ], n = 8)
  )
})

test_that("hr_tt_locoh works with unprojected data", {
  toy_tt <- create_toy_tt()
  toy_locoh <- hr_tt_locoh(toy_tt, n = 4, levels = 0.9)
  expect_equal(nrow(toy_locoh), 2)
  expect_true(sf::st_is_longlat(toy_locoh))
  expect_true(all(as.numeric(toy_locoh$area) > 0))
})

test_that("hulls with no area are only kept with a buffer", {
  # locations on a line: all hulls are segments
  line_tt <- make_locoh_tt(cbind(1:10, 2 * (1:10)))
  no_buffer <- hr_tt_locoh(line_tt, n = 3, levels = 0.9)
  expect_true(sf::st_is_empty(no_buffer$geometry))
  expect_equal(as.numeric(no_buffer$area), 0)

  # with a buffer, (part of) the line becomes a thin polygon, whose area is
  # at most that of the whole line buffered by 0.1
  with_buffer <- hr_tt_locoh(line_tt, n = 3, levels = 0.9, buffer = 0.1)
  expect_true(sf::st_geometry_type(with_buffer) == "MULTIPOLYGON")
  expect_gt(as.numeric(with_buffer$area), 0)
  expect_lt(
    as.numeric(with_buffer$area),
    2 * 0.1 * 9 * sqrt(5) + pi * 0.1^2
  )

  # a cluster of identical locations next to a cloud of locations: the hulls
  # of the cluster are points, which are the smallest hulls
  set.seed(4)
  xy <- rbind(
    matrix(c(100, 100), 6, 2, byrow = TRUE),
    cbind(stats::runif(30), stats::runif(30))
  )
  cluster_tt <- make_locoh_tt(xy)
  no_buffer <- hr_tt_locoh(cluster_tt, n = 4, levels = 0.5)
  with_buffer <- hr_tt_locoh(cluster_tt, n = 4, levels = 0.5, buffer = 0.01)
  cluster <- sf::st_sfc(sf::st_point(c(100, 100)), crs = 32630)
  expect_false(sf::st_intersects(cluster, no_buffer, sparse = FALSE)[1, 1])
  expect_true(sf::st_intersects(cluster, with_buffer, sparse = FALSE)[1, 1])
})

test_that("the k-d tree finds the same neighbours as a brute force search", {
  set.seed(1)
  # a cloud of random locations, with some duplicates and some locations on a
  # grid, to create ties in the distances
  xy <- rbind(
    cbind(stats::runif(300), stats::runif(300)),
    cbind(rep(0:4, 5) / 4, rep(0:4, each = 5) / 4)
  )
  xy <- rbind(xy, xy[1:20, ])
  for (type in c("k", "r", "a")) {
    for (n in switch(type, k = c(2, 7, 30), r = c(0.05, 0.25), a = c(0.1, 2))) {
      cpp <- locoh_neighbours_cpp(xy[, 1], xy[, 2], type, n)
      brute <- brute_neighbours(xy, type, n)
      if (type == "r") {
        # the order of the neighbours within a radius is arbitrary
        cpp <- lapply(cpp, sort)
      }
      expect_identical(cpp, lapply(brute, as.integer))
    }
  }
})

test_that("convex hulls match grDevices::chull", {
  set.seed(2)
  for (i in 1:20) {
    m <- sample(3:50, 1)
    xy <- cbind(stats::rnorm(m), stats::rnorm(m))
    hull <- convex_hull_cpp(xy[, 1], xy[, 2])
    expected <- xy[grDevices::chull(xy), , drop = FALSE]
    # same vertices (in a possibly different order and direction)
    expect_equal(
      hull[do.call(order, as.data.frame(hull)), ],
      expected[do.call(order, as.data.frame(expected)), ]
    )
    # counter-clockwise: positive area by the shoelace formula
    closed <- rbind(hull, hull[1, ])
    shoelace <- sum(
      closed[-nrow(closed), 1] * closed[-1, 2] -
        closed[-1, 1] * closed[-nrow(closed), 2]
    ) / 2
    expect_gt(shoelace, 0)
  }
  # degenerate cases: duplicates and collinear points
  expect_equal(convex_hull_cpp(c(1, 1, 1), c(2, 2, 2)), matrix(c(1, 2), 1))
  expect_equal(
    convex_hull_cpp(c(0, 1, 2, 3), c(0, 1, 2, 3)),
    matrix(c(0, 3, 0, 3), 2)
  )
  # collinear points on the edges of the hull are dropped
  expect_equal(
    nrow(convex_hull_cpp(c(0, 1, 2, 2, 0), c(0, 0, 0, 2, 2))),
    4
  )
})

test_that("the union of the hulls in C++ matches their union by GEOS", {
  # the isopleths merged by GEOS, from the hulls returned by locoh_cpp() (an
  # isopleth with no hulls with an area is empty, as in hr_tt_locoh())
  geos_isopleths <- function(xy, type, n, levels) {
    hulls <- locoh_cpp(xy[, 1], xy[, 2], type, n, levels, 0, 0, 0)
    do.call(c, lapply(hulls$n_hulls, function(n_hulls) {
      polygons <- hulls$hulls[seq_len(n_hulls)][!hulls$degenerate[
        seq_len(n_hulls)
      ]]
      if (length(polygons) == 0) {
        return(sf::st_sfc(sf::st_multipolygon()))
      }
      sf::st_union(sf::st_sfc(polygons))
    }))
  }
  set.seed(5)
  datasets <- list(
    random = cbind(stats::runif(300), stats::runif(300)),
    # locations on a grid, many of them duplicated: hulls share vertices and
    # edges, and have edges along the same lines
    lattice = cbind(sample(0:15, 400, TRUE), sample(0:15, 400, TRUE)),
    # a random walk rounded to whole numbers, as in data with rounded
    # coordinates
    rounded = round(apply(matrix(stats::rnorm(1000), ncol = 2), 2, cumsum) * 10)
  )
  levels <- c(0.95, 0.75, 0.5, 0.25)
  for (xy in datasets) {
    extent <- max(diff(range(xy[, 1])), diff(range(xy[, 2])))
    for (type in c("k", "r", "a")) {
      for (n in switch(type, k = c(3, 10), r = extent / 10, a = extent / 3)) {
        cpp <- locoh_cpp(
          xy[, 1], xy[, 2], type, n, levels, 0, 0, 0,
          union_hulls = TRUE
        )
        expect_false(is.null(cpp$isopleths))
        cpp_isopleths <- sf::st_sfc(cpp$isopleths)
        geos <- geos_isopleths(xy, type, n, levels)
        expect_true(all(sf::st_is_valid(cpp_isopleths)))
        expect_equal(
          as.numeric(sf::st_area(cpp_isopleths)),
          as.numeric(sf::st_area(geos)),
          tolerance = 1e-9
        )
        for (i in seq_along(levels)) {
          sym_diff <- sf::st_area(sf::st_sym_difference(
            cpp_isopleths[i],
            geos[i]
          ))
          expect_lte(
            sum(as.numeric(sym_diff)),
            1e-9 * as.numeric(sf::st_area(geos[i]))
          )
        }
      }
    }
  }
})

test_that("hr_tt_locoh gives the same home ranges as amt", {
  skip_if_not_installed("amt")
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  levels <- c(0.5, 0.75, 0.95)
  for (track in c("Brock", "Chou")) {
    track_tt <- boar_tt[boar_tt$name == track, ]
    xy <- sf::st_coordinates(track_tt)
    track_amt <- amt::make_track(
      data.frame(x = xy[, 1], y = xy[, 2]),
      x,
      y,
      crs = sf::st_crs(track_tt)
    )
    for (type in c("k", "r", "a")) {
      n <- switch(type, k = 10, r = 400, a = 3000)
      amt_hr <- suppressWarnings(
        amt::hr_locoh(track_amt, n = n, type = type, levels = levels)
      )
      # amt buffers each hull by 1e-5, so do the same here
      tt_hr <- hr_tt_locoh(
        track_tt,
        n = n,
        type = type,
        levels = levels,
        buffer = 1e-5
      )
      # hr_tt_locoh() sorts the levels from the largest to the smallest
      expect_equal(
        rev(as.numeric(tt_hr$area)),
        as.numeric(amt_hr$locoh$area),
        tolerance = 1e-6
      )
      # the polygons are the same, not just their areas (sf drops empty
      # geometries, so the difference has no rows if the polygons are equal)
      sym_diff <- sf::st_area(sf::st_sym_difference(
        tt_hr$geometry[1],
        sf::st_geometry(amt_hr$locoh)[length(levels)]
      ))
      expect_lt(sum(as.numeric(sym_diff)), 1e-6 * as.numeric(tt_hr$area[1]))
    }
  }
})

test_that("hr_tt_locoh gives valid isopleths for unprojected data", {
  # Tracks in longitude/latitude for which s2 used to reject the isopleths,
  # as merging the hulls created vertices that s2 sees as duplicates. The
  # tracks are random walks pulled back towards one of two centres.
  simulate_lonlat <- function(seed, n_locations = 50) {
    set.seed(seed)
    xy <- matrix(0, n_locations, 2)
    centres <- rbind(c(0, 0), c(3000, 1500))
    centre <- 1
    for (i in 2:n_locations) {
      if (stats::runif(1) < 0.01) {
        centre <- 3 - centre
      }
      pull <- 0.05 * (centres[centre, ] - xy[i - 1, ])
      xy[i, ] <- xy[i - 1, ] + pull + stats::rnorm(2, sd = 100)
    }
    # about 100 m steps, in degrees
    make_locoh_tt(xy / 1e5, crs = 4326, id = as.character(seed))
  }
  for (seed in c(89, 93, 104, 119, 155)) {
    track <- simulate_lonlat(seed)
    locoh <- hr_tt_locoh(track, n = 10)
    expect_true(all(as.numeric(locoh$area) > 0))
    # the isopleths can be used in further operations with s2
    expect_true(all(sf::st_is_valid(locoh)))
    expect_no_error(sf::st_intersects(locoh, track))
  }
})

# the union of polygons (anticlockwise matrices of coordinates) with
# convex_union_cpp(), the points at the same place sharing an index (as the
# union requires)
union_of <- function(polygons, counts = length(polygons), budget = 0) {
  xy <- do.call(rbind, polygons)
  key <- paste(sprintf("%a", xy[, 1]), sprintf("%a", xy[, 2]))
  convex_union_cpp( # nolint: object_usage_linter.
    xy[, 1],
    xy[, 2],
    offsets = c(0L, cumsum(vapply(polygons, nrow, 1L))),
    vertices = match(key, key) - 1L,
    counts = as.integer(counts),
    max_work_per_vertex = budget
  )
}
rectangle <- function(x0, y0, x1, y1) {
  cbind(c(x0, x1, x1, x0), c(y0, y0, y1, y1))
}

test_that("the union in C++ tells holes from shells exactly", {
  # four rectangles round a hole of 1 cm by 1 cm, at the coordinates of a UTM
  # zone: from the rounded raw coordinates, the area of the hole would have
  # the wrong sign, and the hole would be taken for a shell
  x0 <- 600000.01
  y0 <- 5500000.01
  frame <- list(
    rectangle(x0, y0, x0 + 0.03, y0 + 0.01),
    rectangle(x0, y0 + 0.02, x0 + 0.03, y0 + 0.03),
    rectangle(x0, y0, x0 + 0.01, y0 + 0.03),
    rectangle(x0 + 0.02, y0, x0 + 0.03, y0 + 0.03)
  )
  union <- union_of(frame)
  expect_true(union$built)
  # a single polygon, with a shell and a hole
  expect_length(union$isopleths[[1]], 1)
  expect_length(union$isopleths[[1]][[1]], 2)
  isopleth <- sf::st_sfc(union$isopleths)
  expect_true(sf::st_is_valid(isopleth))
  expect_equal(as.numeric(sf::st_area(isopleth)), 8e-4, tolerance = 1e-6)
  # and the same rings in the opposite order (the hole first)
  union <- union_of(frame[4:1])
  expect_equal(
    as.numeric(sf::st_area(sf::st_sfc(union$isopleths))),
    8e-4,
    tolerance = 1e-6
  )
})

test_that("the union in C++ gives up on inputs it cannot handle", {
  # a star polygon: it turns left at every vertex, but goes round twice
  pentagon <- cbind(cos(2 * pi * (0:4) / 5), sin(2 * pi * (0:4) / 5))
  union <- union_of(list(pentagon[c(1, 3, 5, 2, 4), ]))
  expect_false(union$built)
  expect_equal(union$stats[[4]], 23)
  # a polygon that is not strictly convex
  union <- union_of(list(cbind(c(0, 1, 2, 1), c(0, 0, 0, 1))))
  expect_false(union$built)
  expect_equal(union$stats[[4]], 22)
  # coordinates beyond the range of the exact predicates (with a range of
  # coordinates that overflows, the union could otherwise loop for ever)
  union <- union_of(list(
    cbind(c(-1e300, -9e299, -1e300), c(0, 0, 1e299)),
    cbind(c(9e299, 1e300, 1e300), c(0, 0, 1e299))
  ))
  expect_false(union$built)
  expect_equal(union$stats[[4]], 21)
  # no polygons
  union <- union_of(list(rectangle(0, 0, 1, 1)), counts = 0)
  expect_true(union$built)
  expect_length(union$isopleths[[1]], 0)
})

test_that("the union in C++ stays within its budget", {
  set.seed(11)
  xy <- cbind(stats::runif(300), stats::runif(300))
  hulls <- locoh_cpp(xy[, 1], xy[, 2], "k", 10, c(0.95, 0.5), 0, 0, 0,
    union_hulls = TRUE, union_budget = 1e6
  )
  expect_false(is.null(hulls$isopleths))
  expect_equal(hulls$union_stats[[4]], 0)
  # the work estimated from a sample of the hulls is close to the work done
  expect_equal(hulls$union_stats[[1]], hulls$union_stats[[2]],
    tolerance = 0.5
  )
  # with a tiny budget, the union is left to GEOS
  hulls <- locoh_cpp(xy[, 1], xy[, 2], "k", 10, c(0.95, 0.5), 0, 0, 0,
    union_hulls = TRUE, union_budget = 1e-3
  )
  expect_null(hulls$isopleths)
  expect_equal(hulls$union_stats[[4]], 30)
  expect_length(hulls$hulls, max(hulls$n_hulls))
})

test_that("the isopleths merged by GEOS are those merged in C++", {
  # GEOS is used where the union in C++ would take too long, cannot be built,
  # or gives invalid isopleths
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  first_track <- event_track_id(boar_tt) == event_track_id(boar_tt)[1]
  xy <- sf::st_coordinates(boar_tt)[first_track, ]
  levels <- c(0.95, 0.75, 0.5, 0.25)
  for (type in c("k", "a")) {
    n <- if (type == "k") 10 else 2000
    cpp <- locoh_one_group(xy, n, type, levels, 0, longlat = FALSE)
    geos <- locoh_one_group(xy, n, type, levels, 0,
      longlat = FALSE, cpp_union = FALSE
    )
    expect_equal(
      as.numeric(sf::st_area(cpp)),
      as.numeric(sf::st_area(geos)),
      tolerance = 1e-9
    )
    expect_lte(
      max(as.numeric(sf::st_area(
        sf::st_sym_difference(cpp, geos, by_element = TRUE)
      ))),
      1e-9 * max(as.numeric(sf::st_area(geos)))
    )
    # with a tiny budget, GEOS is used
    expect_identical(
      locoh_one_group(xy, n, type, levels, 0,
        longlat = FALSE, union_budget = 1e-3
      ),
      geos
    )
  }
})

test_that("the union in C++ works on coordinates rounded to 1e-4 degrees", {
  # shifting such coordinates to the centre of the locations rounds them,
  # which made some hulls concave, so that the union in C++ gave up
  set.seed(3)
  xy <- round(cbind(
    cumsum(stats::rnorm(1000, sd = 5e-4)) - 0.001,
    cumsum(stats::rnorm(1000, sd = 5e-4)) + 52.2
  ), 4)
  shift <- c(mean(range(xy[, 1])), mean(range(xy[, 2])))
  hulls <- locoh_cpp(xy[, 1], xy[, 2], "k", 10, c(0.95, 0.75, 0.5, 0.25), 0,
    shift[1], shift[2],
    union_hulls = TRUE
  )
  expect_false(is.null(hulls$isopleths))
  expect_true(all(sf::st_is_valid(sf::st_sfc(hulls$isopleths))))
})

test_that("hr_tt_locoh gives valid isopleths for nearly degenerate hulls", {
  # locations on circles and rays, where rounding the points where the edges
  # of the hulls cross made the isopleths from C++ invalid
  circles <- function(r, a) {
    make_locoh_tt(cbind(r * cos(a * pi / 6), r * sin(a * pi / 6)))
  }
  iso <- hr_tt_locoh(
    circles(c(3, 3, 2, 1, 1, 3), c(10, 9, 10, 10, 8, 10)),
    n = 3.91679,
    type = "a",
    levels = 1
  )
  expect_true(all(sf::st_is_valid(iso)))
  iso <- hr_tt_locoh(
    circles(c(3, 3, 2, 2, 3, 1, 2), c(6, 5, 0, 5, 6, 5, 4)),
    n = 3,
    levels = 1
  )
  expect_true(all(sf::st_is_valid(iso)))
})

test_that("hr_tt_locoh works with groups named like its own variables", {
  # tibble() would use a column of groups named "levels" or "group_labels"
  # instead of the variables of the same names
  for (name in c("levels", "group_labels")) {
    x <- example_tt
    x[[name]] <- ifelse(
      x$track_id == unique(x$track_id)[1],
      "p",
      "q"
    )
    iso <- hr_tt_locoh(dplyr::group_by(x, .data[[name]]), n = 3)
    expect_equal(names(iso)[1], name)
    expect_equal(iso$level, c(0.95, 0.5, 0.95, 0.5))
    expect_equal(iso[[name]], c("p", "p", "q", "q"))
  }
  # a column of groups named like a column of the result gives an error,
  # rather than a result with two columns of the same name
  x <- example_tt
  x$level <- "p"
  expect_error(
    hr_tt_locoh(dplyr::group_by(x, level), n = 3),
    "cannot be named like a column of the result"
  )
})
