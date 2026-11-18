test_that("dist_fast calculates paired geodesic distances", {
  x1 <- c(0, 10)
  y1 <- c(0, 5)
  x2 <- c(1, 11)
  y2 <- c(0, 6)

  expect_equal(
    dist_fast(x1, y1, x2, y2),
    geodist::geodist_vec(
      x1 = x1,
      y = y1,
      x2 = x2,
      y2 = y2,
      sequential = FALSE,
      paired = TRUE,
      measure = "geodesic"
    )
  )
})

test_that("dist_fast calculates paired Euclidean distances", {
  expect_equal(
    dist_fast(
      x1 = c(0, 1),
      y1 = c(0, 1),
      x2 = c(3, 4),
      y2 = c(4, 5),
      longlat = FALSE
    ),
    c(5, 5)
  )
})

test_that("dist_fast requires coordinate vectors of equal length", {
  expect_error(
    dist_fast(
      x1 = c(0, 1),
      y1 = c(0, 1),
      x2 = 1,
      y2 = c(0, 1)
    ),
    "x1, y1, x2 and y2 must have the same length"
  )
  # projected coordinates are checked too (R would recycle the short vector)
  expect_error(
    dist_fast(
      x1 = c(0, 1),
      y1 = c(0, 1),
      x2 = c(3, 4),
      y2 = 4,
      longlat = FALSE
    ),
    "x1, y1, x2 and y2 must have the same length"
  )
})
