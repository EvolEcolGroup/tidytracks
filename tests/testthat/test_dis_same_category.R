test_that("dist_category returns 0 for same category and 1 for different categories", {
  x <- factor(c("A", "A", "B", "C"))

  expected <- matrix(
    c(
      0,
      0,
      1,
      1,
      0,
      0,
      1,
      1,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      0
    ),
    nrow = 4,
    byrow = TRUE
  )

  expect_equal(dist_category(x), expected)
})


test_that("same_category returns 1 for same category and 0 for different categories", {
  x <- factor(c("A", "A", "B", "C"))

  expected <- matrix(
    c(
      1,
      1,
      0,
      0,
      1,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1
    ),
    nrow = 4,
    byrow = TRUE
  )

  expect_equal(same_category(x), expected)
})


test_that("dist_category and same_category preserve names", {
  x <- factor(c("red", "blue", "red"))
  names(x) <- c("sample1", "sample2", "sample3")

  expect_equal(rownames(dist_category(x)), names(x))
  expect_equal(colnames(dist_category(x)), names(x))

  expect_equal(rownames(same_category(x)), names(x))
  expect_equal(colnames(same_category(x)), names(x))
})


test_that("dist_category and same_category handle missing values", {
  x <- factor(c("A", NA, "B"))

  expected_dist <- matrix(
    c(
      0,
      NA,
      1,
      NA,
      NA,
      NA,
      1,
      NA,
      0
    ),
    nrow = 3,
    byrow = TRUE
  )

  expected_same <- matrix(
    c(
      1,
      NA,
      0,
      NA,
      NA,
      NA,
      0,
      NA,
      1
    ),
    nrow = 3,
    byrow = TRUE
  )

  expect_equal(dist_category(x), expected_dist)
  expect_equal(same_category(x), expected_same)
})


test_that("functions error when input is not a factor", {
  expect_error(
    dist_category(c("A", "B")),
    "`x` must be a factor vector.",
    fixed = TRUE
  )

  expect_error(
    same_category(c("A", "B")),
    "`x` must be a factor vector.",
    fixed = TRUE
  )
})


test_that("empty factor input returns an empty matrix", {
  x <- factor(character())

  expect_equal(dist_category(x), matrix(numeric(), nrow = 0, ncol = 0))
  expect_equal(same_category(x), matrix(numeric(), nrow = 0, ncol = 0))
})
