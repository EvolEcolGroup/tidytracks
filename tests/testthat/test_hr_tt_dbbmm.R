# a grid much larger than needed for the bridges of create_irregular_tracks()
# (bridges reaching the very edge of a grid can make move2utils write out of
# bounds, so tests that run the bridge models avoid tight grids)
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
    testthat::expect_true(terra::compareGeom(object$ud[[i]], expected$ud[[i]]))
    testthat::expect_equal(
      terra::values(object$ud[[i]], mat = FALSE),
      terra::values(expected$ud[[i]], mat = FALSE)
    )
  }
}

# a stand-in for the move2utils functions, returning a uniform UD for each
# track on the grid it receives
fake_bridge_fn <- function(object, raster, ...) {
  ids <- unique(as.character(move2::mt_track_id(object)))
  uds <- terra::rast(raster, nlyrs = length(ids))
  terra::values(uds) <- 1 / terra::ncell(raster)
  names(uds) <- ids
  uds
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
  expect_error(hr_tt_dbbmm(x, res = -1), "res must be a single finite")
  expect_error(hr_tt_dbbmm(x, bbox = c(1, 2)), "each bbox must be a named")
})

test_that("hr_tt_dbbmm returns an hr_tt_ud_tbl matching move2utils", {
  skip_if_not_installed("move2utils")
  x <- tt_order_time(create_irregular_tracks())
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = 200
  )
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

test_that("hr_tt_dbbmm uses the grid of hr_tt_kde by default", {
  x <- create_irregular_tracks()
  ud <- hr_tt_bridge(
    x,
    fn = fake_bridge_fn,
    method = "test",
    location_error = NULL,
    window_size = 31,
    margin = 11,
    bbox = NULL,
    res = NULL,
    levels = NULL
  )
  ud_kde <- hr_tt_kde(x)
  expect_true(terra::compareGeom(ud$ud[[1]], ud_kde$ud[[1]]))
  expect_equal(ud$res, ud_kde$res)
  expect_equal(ud$xmin, ud_kde$xmin)
})

test_that("hr_tt_dbbmm UDs can be compared with hr_tt_kde UDs", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = 200
  )
  ud_kde <- hr_tt_kde(x, bbox = test_bbox, res = 200)
  expect_true(terra::compareGeom(ud$ud[[1]], ud_kde$ud[[1]]))
  overlap <- hr_tt_ud_overlap(ud$ud[[1]], ud_kde$ud[[1]])
  expect_true(overlap > 0 && overlap <= 1)
})

test_that("hr_tt_dbbmm gives an informative error if the grid is too small", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  # a grid far from the locations, so that the very first bridge is outside
  expect_error(
    hr_tt_dbbmm(
      x,
      location_error = as_units(20, "m"),
      bbox = c(xmin = 1e6, ymin = 1e6, xmax = 1.1e6, ymax = 1.1e6),
      res = 1000
    ),
    "the grid is not large enough to contain the bridges; use a larger bbox"
  )
})

test_that("hr_tt_dbbmm uses a given grid", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = 250
  )
  expect_equal(terra::res(ud$ud[[1]]), c(250, 250))
  expect_equal(ud$xmin[1], test_bbox[["xmin"]])
  expect_equal(ud$ymin[1], test_bbox[["ymin"]])
  expect_equal(terra::xmin(ud$ud[[1]]), test_bbox[["xmin"]])
})

test_that("hr_tt_dbbmm accepts data grouped by track id", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  expect_equal_ud_tbl(
    hr_tt_dbbmm(
      dplyr::group_by(x, id),
      location_error = as_units(20, "m"),
      bbox = test_bbox
    ),
    hr_tt_dbbmm(x, location_error = as_units(20, "m"), bbox = test_bbox)
  )
})

test_that("hr_tt_dbbmm passes arguments, converting units", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(
    x,
    location_error = as_units(0.02, "km"),
    window_size = 21,
    margin = 5,
    bbox = test_bbox
  )
  expect_identical(ud$window_size, c(21, 21))
  expect_identical(ud$margin, c(5, 5))
  direct <- move2utils::mt_dbbmm_ud(
    x,
    raster = terra::rast(ud$ud[[1]]),
    location_error = 20,
    window_size = 21,
    margin = 5,
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
    hr_tt_dbbmm(x_empty, location_error = as_units(20, "m"), bbox = test_bbox),
    hr_tt_dbbmm(
      x[-c(10, 20), ],
      location_error = as_units(20, "m"),
      bbox = test_bbox
    )
  )
})

test_that("hr_tt_dbbmm works with a single track", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  x <- x[event_track_id(x) == "a", ]
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"), bbox = test_bbox)
  expect_identical(ud$id, "a")
  expect_identical(names(ud$ud[[1]]), "ud")
  expect_equal(terra::global(ud$ud[[1]], "sum")[[1]], 1)
})

test_that("hr_tt_dbbmm returns isopleths when levels are set", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  iso <- hr_tt_dbbmm(
    x,
    location_error = as_units(20, "m"),
    bbox = test_bbox,
    res = 50,
    levels = c(0.5, 0.95)
  )
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_identical(iso$level, c(0.5, 0.95, 0.5, 0.95))
  expect_identical(iso$id, c("a", "a", "b", "b"))
})

test_that("hr_tt_dbgb matches move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbgb(x, location_error = as_units(20, "m"), bbox = test_bbox)
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

test_that("hr_tt_dbbmm leaves out tracks skipped by move2utils", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ids <- as.character(event_track_id(x))
  # track b has fewer events than window_size
  x_short <- x[ids == "a" | (ids == "b" & seq_along(ids) <= 20), ]
  expect_warning(
    ud <- hr_tt_dbbmm(
      x_short,
      location_error = as_units(20, "m"),
      bbox = test_bbox
    ),
    "fewer locations than window_size"
  )
  expect_identical(ud$id, "a")
  expect_identical(names(ud$ud), "a")
})

test_that("hr_tt_ud_sum works with hr_tt_dbbmm UDs", {
  skip_if_not_installed("move2utils")
  x <- create_irregular_tracks()
  ud <- hr_tt_dbbmm(x, location_error = as_units(20, "m"), bbox = test_bbox)
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
