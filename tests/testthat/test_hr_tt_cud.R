test_that("hr_tt_cud works with a SpatRaster input", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # default: returns SpatRaster
  cud <- hr_tt_cud(ud_raster)
  expect_true(inherits(cud, "SpatRaster"))
  expect_equal(names(cud), "cud")

  # values are cumulative: all between 0 and 1 (ignoring NAs)
  cud_vals <- terra::values(cud)
  expect_true(all(cud_vals >= 0 & cud_vals <= 1, na.rm = TRUE))

  # cumulative values sum to 1 (the UD sums to 1, so CUD max is 1)
  expect_equal(max(cud_vals, na.rm = TRUE), 1, tolerance = 1e-6)

  # return_matrix = TRUE returns a matrix with the same dimensions
  cud_mat <- hr_tt_cud(ud_raster, return_matrix = TRUE)
  expect_true(is.matrix(cud_mat))
  expect_equal(dim(cud_mat), c(terra::nrow(ud_raster), terra::ncol(ud_raster)))

  # SpatRaster and matrix results are numerically identical
  expect_equal(as.vector(t(cud_mat)), as.numeric(terra::values(cud)))
})

test_that("hr_tt_cud works with a matrix input", {
  # simple 2x3 matrix
  m <- matrix(c(0.1, 0.3, 0.2, 0.05, 0.25, 0.1), nrow = 2, ncol = 3)

  # default: returns matrix when given a matrix
  cud_mat <- hr_tt_cud(m)
  expect_true(is.matrix(cud_mat))
  expect_equal(dim(cud_mat), dim(m))

  # cumulative values are between 0 and 1
  expect_true(all(cud_mat >= 0 & cud_mat <= 1))

  # the highest input value gets the smallest CUD value
  expect_equal(cud_mat[which.max(m)], m[which.max(m)])

  # CUD values increase (or stay equal) as input values decrease
  flat_in <- as.numeric(m)
  flat_cud <- as.numeric(cud_mat)
  # sort by decreasing input: CUD should be non-decreasing
  sorted_cud <- flat_cud[order(-flat_in)]
  expect_true(all(diff(sorted_cud) >= 0))

  # explicit return_matrix = TRUE also works
  cud_mat2 <- hr_tt_cud(m, return_matrix = TRUE)
  expect_equal(cud_mat, cud_mat2)
})

test_that("hr_tt_cud errors correctly", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # SpatRaster without "ud" layer raises an error
  bad_raster <- ud_raster
  names(bad_raster) <- "not_ud"
  expect_error(hr_tt_cud(bad_raster), "x must have a layer named 'ud'")

  # matrix with return_matrix = FALSE raises an error immediately
  m <- matrix(c(0.5, 0.3, 0.2), nrow = 1)
  expect_error(
    hr_tt_cud(m, return_matrix = FALSE),
    "cannot return a SpatRaster when x is a matrix"
  )
})

test_that("hr_tt_cud SpatRaster and matrix paths are numerically equivalent", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # extract the UD values as a matrix and compute CUD both ways
  ud_mat <- as.matrix(ud_raster[["ud"]], wide = TRUE)
  cud_from_raster <- hr_tt_cud(ud_raster, return_matrix = TRUE)
  cud_from_matrix <- hr_tt_cud(ud_mat)

  expect_equal(cud_from_raster, cud_from_matrix)
})

test_that("cumulative_ud gives cells with the same UD the same value", {
  # from the highest UD to the lowest: 0.4, then two cells of 0.2 (which
  # would be 0.6 and 0.8 in either order), then two of 0.1 (0.9 and 1)
  values <- c(0.1, 0.2, NA, 0.4, 0.2, 0.1)
  expect_equal(cumulative_ud(values), c(0.95, 0.7, NA, 0.4, 0.7, 0.95))
  # whatever the order of the cells
  shuffled <- c(5, 2, 6, 1, 4, 3)
  expect_equal(
    cumulative_ud(values[shuffled]),
    cumulative_ud(values)[shuffled]
  )
  # cells with different UDs are summed from the highest to the lowest
  expect_equal(cumulative_ud(c(0.2, 0.5, 0.3)), c(1, 0.5, 0.8))
  # a single cell, and no cells
  expect_equal(cumulative_ud(1), 1)
  expect_equal(cumulative_ud(numeric(0)), numeric(0))
  expect_equal(cumulative_ud(c(NA, NA)), c(NA_real_, NA_real_))
  # a matrix is taken cell by cell
  expect_equal(
    cumulative_ud(matrix(c(0.5, 0.25, 0.25, 0), 2)),
    c(0.5, 0.875, 0.875, 1)
  )
})

test_that("the isopleths of a symmetric UD are symmetric", {
  # a single location at the centre of a cell: its UD is the same in the
  # cells at the same distance from it
  one <- mt_as_move2(
    sf::st_as_sf(
      data.frame(
        id = "a",
        x = 1025,
        y = 1025,
        time = as.POSIXct("2024-01-01", tz = "UTC")
      ),
      coords = c("x", "y"),
      crs = 32630
    ),
    time_column = "time",
    track_id_column = "id"
  )
  bbox <- c(xmin = 0, ymin = 0, xmax = 2000, ymax = 2000)
  # the area of the part of a geometry that is not in its reflection about
  # x = 1025, and about y = 1025
  asymmetry <- function(geometry) {
    flip <- function(scale, shift) {
      sf::st_set_crs(geometry * diag(scale) + shift, sf::st_crs(geometry))
    }
    c(
      as.numeric(sf::st_area(
        sf::st_sym_difference(geometry, flip(c(-1, 1), c(2050, 0)))
      )),
      as.numeric(sf::st_area(
        sf::st_sym_difference(geometry, flip(c(1, -1), c(0, 2050)))
      ))
    )
  }
  for (method in c("binned", "exact")) {
    iso <- hr_tt_kde(
      one,
      h = 100,
      res = 50,
      bbox = bbox,
      levels = c(0.2, 0.5, 0.95),
      method = method
    )
    for (i in seq_len(nrow(iso))) {
      expect_lt(max(asymmetry(sf::st_geometry(iso)[i]), 0), 1e-6)
    }
  }
})
