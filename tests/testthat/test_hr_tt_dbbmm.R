# a grid much larger than needed for the bridges of create_irregular_tracks()
test_bbox <- c(xmin = -10000, ymin = -10000, xmax = 10000, ymax = 15000)

# compare two hr_tt_ud_tbl objects (SpatRasters cannot be compared directly,
# as they are pointers)
expect_equal_ud_tbl <- function(object, expected) {
  testthat::expect_equal(
    tibble::as_tibble(object)[names(object) != "ud"],
    tibble::as_tibble(expected)[names(expected) != "ud"]
  )
  testthat::expect_identical(names(object$ud), names(expected$ud))
  for (i in seq_along(object$ud)) {
    testthat::expect_true(
      terra::compareGeom(object$ud[[i]], expected$ud[[i]])
    )
    testthat::expect_equal(
      terra::values(object$ud[[i]], mat = FALSE),
      terra::values(expected$ud[[i]], mat = FALSE)
    )
  }
}

test_that("hr_tt_dbbmm gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(hr_tt_dbbmm(data.frame(a = 1:10)), "x must be a move2 object")
  x <- create_irregular_tracks()
  x_no_crs <- x
  sf::st_crs(x_no_crs) <- NA
  expect_error(
    hr_tt_dbbmm(x_no_crs),
    "x must have a coordinate reference system"
  )
  expect_error(
    hr_tt_dbbmm(example_tt),
    "x must have a projected coordinate reference system in metres"
  )
  x$sex <- "f"
  expect_error(
    hr_tt_dbbmm(dplyr::group_by(x, sex)),
    "x must be ungrouped, or grouped by its track id column \\('id'\\) only"
  )
  expect_error(
    hr_tt_dbbmm(dplyr::group_by(x, id, sex)),
    "x must be ungrouped, or grouped by its track id column"
  )
  expect_error(
    hr_tt_dbbmm(x[c(2, 1, 3:nrow(x)), ]),
    "x must be ordered by time within each track; use tt_order_time"
  )
  expect_error(
    hr_tt_dbbmm(x, levels = 1.5),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_dbbmm(x, res = 100),
    "res must be a units object of length 1"
  )
  expect_error(
    hr_tt_dbbmm(x, res = as_units(-1, "m")),
    "res must be a positive distance"
  )
  expect_error(
    hr_tt_dbbmm(x, res = as_units(1, "s")),
    "res must have units of length"
  )
  expect_error(hr_tt_dbbmm(x, bbox = c(1, 2)), "each bbox must be a named")
  expect_error(
    hr_tt_dbbmm(x, location_error = 20),
    "location_error must be a units object"
  )
  expect_error(
    hr_tt_dbbmm(x, location_error = "not_a_column"),
    "location_error \\('not_a_column'\\) is not a column of x"
  )
  # a column of plain numbers is not assumed to be in metres
  x$error_metres <- rep(20, nrow(x))
  expect_error(
    hr_tt_dbbmm(x, location_error = "error_metres"),
    "the column 'error_metres' used for location_error must be a units object"
  )
  expect_error(
    hr_tt_dbbmm(x, location_error = as_units(c(10, 20), "m")),
    "location_error must have one value, or one value per event"
  )
  expect_error(
    hr_tt_dbbmm(x, location_error = as_units(-1, "m")),
    "location_error must not be negative"
  )
  expect_error(
    hr_tt_dbbmm(x, time_step = 1),
    "time_step must be a units object with time units"
  )
})

test_that("hr_tt_dbbmm returns an hr_tt_ud_tbl matching move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"))
  expect_s3_class(ud, "hr_tt_ud_tbl")
  expect_identical(
    names(ud),
    c(
      "id", "method", "window_size", "margin", "xmin", "ymin", "xmax",
      "ymax", "res", "ud"
    )
  )
  # rows are in the same order as hr_tt_kde() for ungrouped data
  expect_identical(ud$id, c("a", "b"))
  expect_identical(names(ud$ud), c("a", "b"))
  expect_identical(ud$method, c("dbbmm", "dbbmm"))
  expect_identical(ud$window_size, c(31, 31))
  expect_identical(ud$margin, c(11, 11))
  for (i in 1:2) {
    expect_identical(names(ud$ud[[i]]), "ud")
    expect_equal(terra::global(ud$ud[[i]], "sum")[[1]], 1)
  }
  # same values as move2utils on the same grid
  direct <- move2utils::mt_dbbmm_ud(
    x,
    raster = terra::rast(ud$ud[[1]]),
    location_error = 20,
    verbose = FALSE
  )
  expect_equal(
    terra::values(ud$ud[[1]], mat = FALSE),
    terra::values(direct[["a"]], mat = FALSE)
  )
  expect_equal(
    terra::values(ud$ud[[2]], mat = FALSE),
    terra::values(direct[["b"]], mat = FALSE)
  )
})

test_that("hr_tt_dbbmm chooses a grid covering the bridges", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"))
  # the grid contains all the locations, with a margin
  locations <- sf::st_bbox(x)
  expect_lt(ud$xmin[1], locations[["xmin"]] - 5 * ud$res[1])
  expect_lt(ud$ymin[1], locations[["ymin"]] - 5 * ud$res[1])
  expect_gt(ud$xmax[1], locations[["xmax"]] + 5 * ud$res[1])
  expect_gt(ud$ymax[1], locations[["ymax"]] + 5 * ud$res[1])
  # with at most about 500 cells along its longest side
  expect_lte(max(dim(ud$ud[[1]])[1:2]), 512)
  # the default grid differs from the one of hr_tt_kde()
  expect_false(isTRUE(all.equal(ud$res[1], hr_tt_kde(x)$res[1])))
})

test_that("hr_tt_dbbmm uses a given grid", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = as_units(250, "m")
  )
  expect_equal(terra::res(ud$ud[[1]]), c(250, 250))
  expect_equal(ud$xmin[1], test_bbox[["xmin"]])
  expect_equal(ud$ymin[1], test_bbox[["ymin"]])
  expect_equal(terra::xmin(ud$ud[[1]]), test_bbox[["xmin"]])
  # res can be given in any units of length
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      x,
      location_error = as_units(20, "m"),
      bbox = test_bbox,
      res = as_units(0.25, "km")
    ),
    ud
  )
  # the UDs can be compared with kernel UDs on the same grid
  ud_kde <- hr_tt_kde(x, bbox = test_bbox, res = 250)
  expect_true(terra::compareGeom(ud$ud[[1]], ud_kde$ud[[1]]))
  overlap <- hr_tt_ud_overlap(ud$ud[[1]], ud_kde$ud[[1]])
  expect_true(overlap > 0 && overlap <= 1)
})

test_that("hr_tt_dbbmm limits the number of cells of a given bbox", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  # without res, the cells are no smaller than needed for the longest side of
  # the given bbox (rather than of the bridges) to have 500 cells
  large_bbox <- c(xmin = -50000, ymin = -50000, xmax = 50000, ymax = 50000)
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"), bbox = large_bbox)
  expect_gte(ud$res[1], 100000 / 500)
  expect_lte(max(dim(ud$ud[[1]])[1:2]), 500)
})

test_that("hr_tt_dbbmm checks that the grid contains the bridges", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  # the extent of the locations is too small, as the bridges extend beyond
  # them (the check is done before calling move2utils)
  locations <- sf::st_bbox(x)
  expect_error(
    hr_tt_dbbmm(
      x,
      location_error = as_units(20, "m"),
      bbox = c(
        xmin = locations[["xmin"]], ymin = locations[["ymin"]],
        xmax = locations[["xmax"]], ymax = locations[["ymax"]]
      ),
      res = as_units(50, "m")
    ),
    paste(
      "the grid is not large enough to contain the bridges: bbox must",
      "extend at least two cells beyond"
    )
  )
})

test_that("hr_tt_dbbmm warns if the cells are much wider than the bridges", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expect_warning(
    hr_tt_dbbmm(
      x,
      location_error = as_units(20, "m"),
      bbox = test_bbox,
      res = as_units(2.5, "km")
    ),
    "much wider than the median width of the bridges"
  )
})

test_that("hr_tt_dbbmm accepts data grouped by track id", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expect_equal_ud_tbl(
    hr_tt_dbbmm(dplyr::group_by(x, id), location_error = as_units(20, "m")),
    hr_tt_dbbmm(x, location_error = as_units(20, "m"))
  )
})

test_that("hr_tt_dbbmm accepts location errors in several forms", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expected <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = as_units(100, "m")
  )
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      x,
      location_error = as_units(0.02, "km"),
      bbox = test_bbox,
      res = as_units(100, "m")
    ),
    expected
  )
  # one value per event
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      x,
      location_error = as_units(rep(20, nrow(x)), "m"),
      bbox = test_bbox,
      res = as_units(100, "m")
    ),
    expected
  )
  # a column with units, in any units of length
  x$error_units <- as_units(rep(0.02, nrow(x)), "km")
  expect_equal_ud_tbl(
    hr_tt_dbbmm(x, location_error = "error_units", bbox = test_bbox,
      res = as_units(100, "m")
    ),
    expected
  )
  # missing values are replaced by the median
  x$error_units[5] <- NA
  expect_equal_ud_tbl(
    hr_tt_dbbmm(x, location_error = "error_units", bbox = test_bbox,
      res = as_units(100, "m")
    ),
    expected
  )
})

test_that("hr_tt_dbbmm passes the sliding window and time step", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    window_size = 21,
    margin = 5,
    time_step = as_units(30, "s"),
    bbox = test_bbox,
    res = as_units(100, "m")
  )
  expect_identical(ud$window_size, c(21, 21))
  expect_identical(ud$margin, c(5, 5))
  direct <- move2utils::mt_dbbmm_ud(
    x,
    raster = terra::rast(ud$ud[[1]]),
    location_error = 20,
    window_size = 21,
    margin = 5,
    time_step = 0.5,
    verbose = FALSE
  )
  expect_equal(
    terra::values(ud$ud[[1]], mat = FALSE),
    terra::values(direct[["a"]], mat = FALSE)
  )
})

test_that("hr_tt_dbbmm ignores events without a location", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  x_empty <- x
  sf::st_geometry(x_empty)[c(10, 20)] <- sf::st_point()
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      x_empty,
      location_error = as_units(20, "m"),
      bbox = test_bbox,
      res = as_units(100, "m")
    ),
    hr_tt_dbbmm(
      x[-c(10, 20), ],
      location_error = as_units(20, "m"),
      bbox = test_bbox,
      res = as_units(100, "m")
    )
  )
  # location errors given per event are matched to the located events
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      x_empty,
      location_error = as_units(c(rep(20, 50), rep(30, nrow(x) - 50)), "m"),
      bbox = test_bbox,
      res = as_units(100, "m")
    ),
    hr_tt_dbbmm(
      x[-c(10, 20), ],
      location_error = as_units(c(rep(20, 48), rep(30, nrow(x) - 50)), "m"),
      bbox = test_bbox,
      res = as_units(100, "m")
    )
  )
})

test_that("hr_tt_dbbmm works with a single track", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  x <- x[event_track_id(x) == "a", ]
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"))
  expect_identical(ud$id, "a")
  expect_identical(names(ud$ud[[1]]), "ud")
  expect_equal(terra::global(ud$ud[[1]], "sum")[[1]], 1)
})

test_that("hr_tt_dbbmm leaves out tracks skipped by move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ids <- as.character(event_track_id(x))
  # track b has fewer events than window_size
  x_short <- x[ids == "a" | (ids == "b" & seq_along(ids) <= 20), ]
  expect_warning(
    ud <- hr_tt_dbbmm(x_short, location_error = as_units(20, "m")),
    "fewer locations than window_size"
  )
  expect_identical(ud$id, "a")
  expect_identical(names(ud$ud), "a")
})

test_that("hr_tt_dbbmm returns isopleths when levels are set", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  iso <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    levels = c(0.5, 0.95)
  )
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_identical(iso$level, c(0.5, 0.95, 0.5, 0.95))
  expect_identical(iso$id, c("a", "a", "b", "b"))
})

test_that("hr_tt_dbgb matches move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbgb(x, location_error = as_units(20, "m"))
  expect_s3_class(ud, "hr_tt_ud_tbl")
  expect_identical(ud$method, c("dbgb", "dbgb"))
  expect_identical(ud$margin, c(15, 15))
  direct <- move2utils::mt_dbgb_ud(
    x,
    raster = terra::rast(ud$ud[[1]]),
    location_error = 20,
    verbose = FALSE
  )
  expect_equal(
    terra::values(ud$ud[[2]], mat = FALSE),
    terra::values(direct[["b"]], mat = FALSE)
  )
})

test_that("hr_tt_ud_sum works with hr_tt_dbbmm UDs", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"))
  ud_sum <- hr_tt_ud_sum(ud)
  expect_identical(
    names(ud_sum),
    c(
      "method", "window_size", "margin", "xmin", "ymin", "xmax", "ymax",
      "res", "ud"
    )
  )
  expect_equal(terra::global(ud_sum$ud[[1]], "sum")[[1]], 1)
  expect_equal(
    terra::values(ud_sum$ud[[1]], mat = FALSE),
    (terra::values(ud$ud[[1]], mat = FALSE) +
       terra::values(ud$ud[[2]], mat = FALSE)) / 2
  )
})
