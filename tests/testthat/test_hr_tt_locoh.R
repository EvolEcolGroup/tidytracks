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
