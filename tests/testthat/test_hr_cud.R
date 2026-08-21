test_that("hr_cud works with a SpatRaster input", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # default: returns SpatRaster
  cud <- hr_cud(ud_raster)
  expect_true(inherits(cud, "SpatRaster"))
  expect_equal(names(cud), "cud")

  # values are cumulative: all between 0 and 1 (ignoring NAs)
  cud_vals <- terra::values(cud)
  expect_true(all(cud_vals >= 0 & cud_vals <= 1, na.rm = TRUE))

  # cumulative values sum to 1 (the UD sums to 1, so CUD max is 1)
  expect_equal(max(cud_vals, na.rm = TRUE), 1, tolerance = 1e-6)

  # return_matrix = TRUE returns a matrix with the same dimensions
  cud_mat <- hr_cud(ud_raster, return_matrix = TRUE)
  expect_true(is.matrix(cud_mat))
  expect_equal(dim(cud_mat), c(terra::nrow(ud_raster), terra::ncol(ud_raster)))

  # SpatRaster and matrix results are numerically identical
  expect_equal(as.vector(t(cud_mat)), as.numeric(terra::values(cud)))
})

test_that("hr_cud works with a matrix input", {
  # simple 2x3 matrix
  m <- matrix(c(0.1, 0.3, 0.2, 0.05, 0.25, 0.1), nrow = 2, ncol = 3)

  # default: returns matrix when given a matrix
  cud_mat <- hr_cud(m)
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
  cud_mat2 <- hr_cud(m, return_matrix = TRUE)
  expect_equal(cud_mat, cud_mat2)
})

test_that("hr_cud errors correctly", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # SpatRaster without "ud" layer raises an error
  bad_raster <- ud_raster
  names(bad_raster) <- "not_ud"
  expect_error(hr_cud(bad_raster), "x must have a layer named 'ud'")

  # matrix with return_matrix = FALSE raises an error immediately
  m <- matrix(c(0.5, 0.3, 0.2), nrow = 1)
  expect_error(
    hr_cud(m, return_matrix = FALSE),
    "cannot return a SpatRaster when x is a matrix"
  )
})

test_that("hr_cud SpatRaster and matrix paths are numerically equivalent", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  ud_raster <- boar_kde$ud[[1]]

  # extract the UD values as a matrix and compute CUD both ways
  ud_mat <- as.matrix(ud_raster[["ud"]], wide = TRUE)
  cud_from_raster <- hr_cud(ud_raster, return_matrix = TRUE)
  cud_from_matrix <- hr_cud(ud_mat)

  expect_equal(cud_from_raster, cud_from_matrix)
})
