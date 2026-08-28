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

test_that("dist_fast calculates consecutive matrix distances", {
  coordinates <- rbind(
    c(0, 0),
    c(1, 0),
    c(1, 1)
  )

  expect_equal(
    dist_fast(coordinates),
    geodist::geodist_vec(
      x1 = coordinates[-nrow(coordinates), 1],
      y = coordinates[-nrow(coordinates), 2],
      x2 = coordinates[-1, 1],
      y2 = coordinates[-1, 2],
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

test_that("dist_fast calculates consecutive Euclidean matrix distances", {
  coordinates <- rbind(
    c(0, 0),
    c(3, 4),
    c(6, 8)
  )

  expect_equal(dist_fast(coordinates, longlat = FALSE), c(5, 5))
})

test_that("dist_fast validates matrix input", {
  expect_error(
    dist_fast(c(0, 1)),
    "x1 is not a matrix and multiple arguments not specified"
  )
  expect_error(dist_fast(matrix(c(0, 0), nrow = 1)), "x1 has too few rows")
  expect_error(
    dist_fast(matrix(c(0, 1), ncol = 1)),
    "x1 has too few columns"
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
    "arguments must have equal lengths"
  )
})
