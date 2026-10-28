test_that("hr_tt_kde works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # group by name
  boar_tt <- boar_tt %>%
    dplyr::group_by(name)
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  # we expect 4 rows, one per group
  expect_equal(nrow(boar_kde), 4)
  # this should be  a hr_tt_kde_tbl object
  expect_true(inherits(boar_kde, "hr_tt_ud_tbl"))
  # UDs are stored as live SpatRasters during analysis
  expect_false(inherits(boar_kde$ud, "PackedSpatRaster_list"))
  expect_true(all(vapply(boar_kde$ud, inherits, logical(1), "SpatRaster")))
  # the group_id column should have been renamed to "name"
  expect_true("name" %in% names(boar_kde))
  expect_equal(length(unique(boar_kde$xmin)), 1)
  expect_equal(length(unique(boar_kde$ymin)), 1)
  expect_equal(length(unique(boar_kde$xmax)), 1)
  expect_equal(length(unique(boar_kde$ymax)), 1)
  expect_equal(length(unique(boar_kde$res)), 1)

  # test autoplot for the hr_tt_ud_tbl object
  p <- autoplot(boar_kde)
  expect_true(inherits(p, "ggplot"))
  expect_true(inherits(p, "patchwork"))
  # it should have 4 elements
  expect_equal(length(p), 4)
  # plot just two plots
  p2 <- autoplot(boar_kde, id_to_plot = c(1, 3))
  # it should have 2 elements
  expect_equal(length(p2), 2)
  # now plot just one
  p3 <- autoplot(boar_kde, id_to_plot = 2)
  # it should have 1 element
  expect_equal(length(p3), 1)

  # use a tt that is not grouped
  boar_tt2 <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde2 <- hr_tt_kde(boar_tt2, res = 50)
  # this should be the same as the previous one
  # test updated to check all 4 UDs are the same, rather than just the first
  expect_equal(
    stats::setNames(lapply(boar_kde$ud, terra::values), boar_kde$name),
    stats::setNames(lapply(boar_kde2$ud, terra::values), boar_kde2$name)
  )
})

test_that("hr_tt_kde bbox columns are always numeric (not list-cols)", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt <- boar_tt %>% dplyr::group_by(name)

  # Call with default (NULL) bbox — internally uses sf::st_bbox()
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  expect_true(is.numeric(boar_kde$xmin))
  expect_true(is.numeric(boar_kde$xmax))
  expect_true(is.numeric(boar_kde$ymin))
  expect_true(is.numeric(boar_kde$ymax))

  # Call with bbox supplied as a named list
  ext <- sf::st_bbox(boar_tt)
  bbox_list <- list(
    xmin = unname(ext["xmin"]) - 1000,
    ymin = unname(ext["ymin"]) - 1000,
    xmax = unname(ext["xmax"]) + 1000,
    ymax = unname(ext["ymax"]) + 1000
  )
  boar_kde_list <- hr_tt_kde(boar_tt, res = 50, bbox = bbox_list)
  expect_true(is.numeric(boar_kde_list$xmin))
  expect_true(is.numeric(boar_kde_list$xmax))
  expect_true(is.numeric(boar_kde_list$ymin))
  expect_true(is.numeric(boar_kde_list$ymax))
})

test_that("hr_tt_kde accepts a separate grid for each group", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds")) %>%
    dplyr::group_by(name)
  group_names <- dplyr::group_keys(boar_tt)$name
  # grids within reach of the kernels of the locations of every group
  bbox <- lapply(seq_along(group_names), function(i) {
    c(
      xmin = 699000 + i * 200,
      ymin = 3159800,
      xmax = 699000 + i * 200 + 500,
      ymax = 3160800
    )
  })

  boar_kde <- hr_tt_kde(boar_tt, bbox = bbox, res = c(25, 50, 100, 125))

  expect_equal(boar_kde$xmin, c(699200, 699400, 699600, 699800))
  expect_equal(boar_kde$xmax, c(699700, 699900, 700100, 700300))
  expect_equal(boar_kde$res, c(25, 50, 100, 125))
  expect_equal(
    unname(vapply(boar_kde$ud, terra::ncell, numeric(1))),
    c(800, 200, 50, 32)
  )
})

test_that("hr_tt_kde validates a collection of group-specific grids", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds")) %>%
    dplyr::group_by(name)
  bbox <- list(c(xmin = 0, ymin = 0, xmax = 100, ymax = 100))

  expect_error(
    hr_tt_kde(boar_tt, bbox = bbox, res = 10),
    "one named vector per group"
  )
  expect_error(
    hr_tt_kde(boar_tt, bbox = rep(bbox, 4), res = c(10, 10)),
    "one value per group"
  )
})

test_that("hr_tt_kde rejects grids beyond the reach of a group's kernels", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds")) %>%
    dplyr::group_by(name)
  # the grid of the second group (Calou) is far from its locations, so the
  # UD is 0 on all its cells, and cannot be standardised to sum to 1
  ext <- sf::st_bbox(boar_tt)
  bbox <- rep(list(ext), 4)
  bbox[[2]] <- c(xmin = 0, ymin = 0, xmax = 1000, ymax = 1000)
  for (method in c("binned", "exact")) {
    expect_error(
      hr_tt_kde(boar_tt, bbox = bbox, res = 50, method = method),
      "the UD of group Calou is 0 on the whole grid"
    )
  }
})

test_that("hr_tt_kde matches individual bandwidths to the right group", {
  # track "b" is stored before track "a", so the order in which the groups
  # appear in the data differs from the order of the group keys
  set.seed(1)
  coords <- data.frame(
    id = rep(c("b", "a"), each = 50),
    x = stats::rnorm(100, 0, rep(c(10000, 100), each = 50)),
    y = stats::rnorm(100, 0, rep(c(10000, 100), each = 50))
  )
  coords$time <- as.POSIXct("2024-01-01", tz = "UTC") +
    seq_len(nrow(coords)) * 60
  tracks <- move2::mt_as_move2(
    sf::st_as_sf(coords, coords = c("x", "y"), crs = 32630),
    time_column = "time",
    track_id_column = "id"
  )
  expected_h_ref <- function(id) {
    xy <- coords[coords$id == id, ]
    sqrt(0.5 * (stats::var(xy$x) + stats::var(xy$y))) * nrow(xy)^(-1 / 6)
  }

  # the default grid is shared by the two tracks, so its cells are too large
  # for the bandwidth of track "a", whose locations are much closer together
  expect_warning(
    kde <- hr_tt_kde(tracks, h = "h_ref_indiv"),
    "the bandwidth \\(h\\) of 1 group\\(s\\) is too small"
  )
  expect_equal(kde$h[kde$id == "a"], expected_h_ref("a"))
  expect_equal(kde$h[kde$id == "b"], expected_h_ref("b"))

  # the internal helper returns bandwidths in group index order
  xy <- sf::st_coordinates(tracks)
  group_index <- ifelse(coords$id == "a", 1L, 2L)
  expect_equal(
    h_ref_indiv(xy, group_index),
    c(expected_h_ref("a"), expected_h_ref("b"))
  )

  # a vector of bandwidths is matched to the groups in group key order
  expect_warning(
    kde_h <- hr_tt_kde(tracks, h = c(10, 20)),
    "the bandwidth \\(h\\) of 2 group\\(s\\) is too small"
  )
  expect_equal(kde_h$h[kde_h$id == "a"], 10)
  expect_equal(kde_h$h[kde_h$id == "b"], 20)
})

test_that("hr_tt_kde ignores events without a location", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt_empty <- boar_tt
  sf::st_geometry(boar_tt_empty)[5] <- sf::st_point()

  kde_empty <- hr_tt_kde(boar_tt_empty, res = 50)
  kde_removed <- hr_tt_kde(boar_tt[-5, ], res = 50)
  expect_equal(kde_empty$h, kde_removed$h)
  expect_equal(
    lapply(kde_empty$ud, terra::values),
    lapply(kde_removed$ud, terra::values)
  )

  # a group without any location cannot be estimated
  boar_tt_empty <- boar_tt
  first_track <- event_track_id(boar_tt) == event_track_id(boar_tt)[1]
  sf::st_geometry(boar_tt_empty)[first_track] <- sf::st_point()
  expect_error(
    hr_tt_kde(boar_tt_empty, res = 50),
    "each group must contain at least one event with a location"
  )
})

test_that("hr_tt_kde handles groups with a single location", {
  set.seed(2)
  coords <- data.frame(
    id = c(rep("a", 20), "b"),
    x = c(stats::rnorm(20, 0, 100), 50),
    y = c(stats::rnorm(20, 0, 100), 50)
  )
  coords$time <- as.POSIXct("2024-01-01", tz = "UTC") +
    seq_len(nrow(coords)) * 60
  tracks <- move2::mt_as_move2(
    sf::st_as_sf(coords, coords = c("x", "y"), crs = 32630),
    time_column = "time",
    track_id_column = "id"
  )

  # the mean reference bandwidth is computed from the groups for which it is
  # defined, and used for all groups
  kde <- hr_tt_kde(tracks)
  h_ref_a <- h_ref_indiv(sf::st_coordinates(tracks)[1:20, ], rep(1, 20))
  expect_equal(kde$h, rep(h_ref_a, 2))
  expect_equal(
    unname(unlist(terra::global(kde$ud[[2]], "sum"))),
    1
  )
  # a numeric bandwidth can be used for a single location (this one is
  # smaller than the cells of the default grid)
  expect_warning(hr_tt_kde(tracks, h = 10), "is too small")
  # but the reference bandwidth of a single location is undefined
  expect_error(
    hr_tt_kde(tracks, h = "h_ref_indiv"),
    "fewer than two distinct locations"
  )
})

test_that("hr_tt_kde returns isopleths of class hr_tt_poly_tbl", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_iso <- hr_tt_kde(boar_tt, levels = c(0.5, 0.95), res = 50)
  expect_s3_class(boar_iso, "hr_tt_poly_tbl")
  expect_identical(
    class(boar_iso),
    class(hr_tt_ud_iso(hr_tt_kde(boar_tt, res = 50), levels = c(0.5, 0.95)))
  )

  # including for a single group
  first_track <- event_track_id(boar_tt) == event_track_id(boar_tt)[1]
  one_iso <- hr_tt_kde(boar_tt[first_track, ], levels = 0.5, res = 50)
  expect_identical(class(one_iso), class(boar_iso))
})

test_that("hr_tt_kde rejects groups without events", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # a grouping factor with an unused level, kept as a group with .drop = FALSE
  boar_tt$group <- factor(
    as.character(boar_tt$name),
    levels = c("unused", levels(boar_tt$name))
  )
  boar_grouped <- dplyr::group_by(boar_tt, group, .drop = FALSE)
  expect_error(
    hr_tt_kde(boar_grouped, res = 50),
    "groups without events \\(unused\\).*group_by\\(x, group, .drop = TRUE\\)"
  )
  # the suggested regrouping removes them
  expect_equal(
    hr_tt_kde(
      dplyr::group_by(boar_grouped, group, .drop = TRUE),
      levels = 0.5,
      res = 50
    ),
    hr_tt_kde(dplyr::group_by(boar_tt, group), levels = 0.5, res = 50)
  )

  # groups emptied by filter(.preserve = TRUE)
  boar_filtered <- boar_tt |>
    dplyr::group_by(name) |>
    dplyr::filter(name != "Brock", .preserve = TRUE)
  expect_error(
    hr_tt_kde(boar_filtered, res = 50),
    "groups without events \\(Brock\\).*group_by\\(x, name, .drop = TRUE\\)"
  )

  # the names of grouping variables that are not syntactic are quoted
  boar_tt$`life stage` <- boar_tt$group
  expect_error(
    hr_tt_kde(dplyr::group_by(boar_tt, `life stage`, .drop = FALSE)),
    "group_by(x, `life stage`, .drop = TRUE)",
    fixed = TRUE
  )
})

test_that("hr_tt_kde gives nearly the same UD with both methods", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # the bandwidths (about 210 m) span about 4 cells
  binned <- hr_tt_kde(boar_tt, res = 50)
  exact <- hr_tt_kde(boar_tt, res = 50, method = "exact")
  # the same groups, bandwidths and grids
  expect_equal(binned$h, exact$h)
  expect_equal(
    lapply(binned$ud, function(ud) as.vector(terra::ext(ud))),
    lapply(exact$ud, function(ud) as.vector(terra::ext(ud)))
  )
  # UDs that differ by less than 1% (they each sum to 1)
  ud_difference <- mapply(
    function(b, e) sum(abs(terra::values(b) - terra::values(e))),
    binned$ud,
    exact$ud
  )
  expect_true(all(ud_difference < 0.01))
  # and so do the areas of their isopleths
  binned_iso <- hr_tt_ud_iso(binned, levels = c(0.5, 0.95))
  exact_iso <- hr_tt_ud_iso(exact, levels = c(0.5, 0.95))
  expect_equal(
    as.numeric(binned_iso$area),
    as.numeric(exact_iso$area),
    tolerance = 0.01
  )
  # the isopleths can also be computed directly
  expect_equal(
    hr_tt_kde(boar_tt, res = 50, levels = c(0.5, 0.95))$area,
    binned_iso$area
  )
  # an unknown method is rejected
  expect_error(hr_tt_kde(boar_tt, method = "fast"), "should be one of")
})

test_that("the binned UD is centred on the cells of the grid", {
  # a single location at the centre of a cell
  one <- move2::mt_as_move2(
    sf::st_as_sf(
      data.frame(
        id = "a",
        x = 1025,
        y = 2075,
        time = as.POSIXct("2024-01-01", tz = "UTC")
      ),
      coords = c("x", "y"),
      crs = 32630
    ),
    time_column = "time",
    track_id_column = "id"
  )
  bbox <- c(xmin = 0, ymin = 0, xmax = 2000, ymax = 4000)
  binned <- hr_tt_kde(one, h = 100, res = 50, bbox = bbox)$ud[[1]]
  exact <- hr_tt_kde(one, h = 100, res = 50, bbox = bbox, method = "exact")
  exact <- exact$ud[[1]]
  # the UD peaks at the cell of the location
  expect_equal(
    unname(terra::xyFromCell(binned, which.max(terra::values(binned)))[1, ]),
    c(1025, 2075)
  )
  # and is symmetric around it (it would be stretched if the grid points of
  # bkde2D() were not at the centres of the cells)
  ud <- terra::as.matrix(binned, wide = TRUE)
  window <- ud[
    terra::rowFromY(binned, 2075) + (-8:8),
    terra::colFromX(binned, 1025) + (-8:8)
  ]
  expect_equal(window, window[17:1, ])
  expect_equal(window, window[, 17:1])
  # as the exact UD
  expect_equal(
    terra::values(binned),
    terra::values(exact),
    tolerance = 0.01
  )
})

test_that("the binned UD includes the locations outside the grid", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # a grid that leaves out most of the locations of some of the animals,
  # which still add the tails of their kernels to the cells of the grid
  ext <- sf::st_bbox(boar_tt)
  bbox <- c(
    xmin = ext[["xmin"]] + 500,
    ymin = ext[["ymin"]] + 500,
    xmax = ext[["xmax"]] - 500,
    ymax = ext[["ymax"]] - 500
  )
  binned <- hr_tt_kde(boar_tt, res = 50, bbox = bbox)
  exact <- hr_tt_kde(boar_tt, res = 50, bbox = bbox, method = "exact")
  ud_difference <- mapply(
    function(b, e) sum(abs(terra::values(b) - terra::values(e))),
    binned$ud,
    exact$ud
  )
  expect_true(all(ud_difference < 0.01))
  # so is the sum of the density, before standardisation
  density_sum <- function(ud) {
    as.numeric(terra::metags(ud)[terra::metags(ud)$name == "density_sum", 2])
  }
  expect_equal(
    vapply(binned$ud, density_sum, numeric(1)),
    vapply(exact$ud, density_sum, numeric(1)),
    tolerance = 0.01
  )
})

test_that("the binned UD warns of bandwidths too small for the grid", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # once for all the groups
  expect_warning(
    hr_tt_kde(boar_tt, h = 10, res = 50),
    "the bandwidth \\(h\\) of 4 group\\(s\\) is too small"
  )
  # the exact method evaluates the kernel at the centre of each cell
  expect_no_warning(hr_tt_kde(boar_tt, h = 10, res = 50, method = "exact"))
})

test_that("kde_linbin_cpp splits each location between its grid points", {
  # a 3 x 2 grid of points, 10 apart, from (0, 100)
  bin <- function(x, y) kde_linbin_cpp(x, y, 0, 100, 10, 3L, 2L)
  # a location on a grid point is all on it
  expect_equal(bin(10, 100), matrix(c(0, 1, 0, 0, 0, 0), 3, 2))
  # a location between grid points is split in proportion to how close it is
  # to each of them
  expect_equal(bin(2.5, 105), matrix(c(0.375, 0.125, 0, 0.375, 0.125, 0), 3, 2))
  # a location on the last grid point is all on it
  expect_equal(bin(20, 110), matrix(c(0, 0, 0, 0, 0, 1), 3, 2))
  # locations outside the grid are moved to its nearest edge
  expect_equal(bin(-50, 200), bin(0, 110))
  # the counts sum to the number of locations
  set.seed(5)
  x <- stats::runif(100, 0, 20)
  y <- stats::runif(100, 100, 110)
  expect_equal(sum(bin(x, y)), 100)
  # a grid with a single point along an axis
  expect_equal(
    kde_linbin_cpp(c(3, 7), c(100, 100), 0, 100, 10, 2L, 1L),
    matrix(c(1, 1), 2, 1)
  )
})

test_that("the binned UD is the KDE of KernSmooth::bkde2D()", {
  skip_if_not_installed("KernSmooth")
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  first_track <- event_track_id(boar_tt) == event_track_id(boar_tt)[1]
  xy <- sf::st_coordinates(boar_tt[first_track, ])
  res <- 50
  bbox <- align_kde_bbox(expand_kde_bbox(sf::st_bbox(boar_tt)), res)
  h <- h_ref_indiv(xy, rep(1, nrow(xy)))
  binned <- kde_density_binned(xy, bbox, res, h)

  # bkde2D() on the centres of the cells (which contain all the locations)
  n_cells <- round(c(
    bbox[["xmax"]] - bbox[["xmin"]],
    bbox[["ymax"]] - bbox[["ymin"]]
  ) / res)
  bkde <- KernSmooth::bkde2D(
    xy,
    bandwidth = c(h, h),
    gridsize = n_cells,
    range.x = list(
      c(bbox[["xmin"]] + res / 2, bbox[["xmax"]] - res / 2),
      c(bbox[["ymin"]] + res / 2, bbox[["ymax"]] - res / 2)
    )
  )
  expect_equal(binned, kde_ud_layout(bkde$fhat), tolerance = 1e-10)
})
