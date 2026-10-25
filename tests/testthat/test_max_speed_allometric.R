test_that("max_speed_allometric gives the correct errors", {
  skip_if_not_installed("move2utils")
  expect_error(
    max_speed_allometric("a", mode = "running"),
    "mass must be a units object or a numeric vector"
  )
  expect_error(max_speed_allometric(4), "mode must be provided")
  expect_error(
    max_speed_allometric(c(1, 2, 3), mode = c("running", "flying")),
    "mode must be a single value or have the same length as mass"
  )
  expect_error(max_speed_allometric(4, mode = "crawling"))
  expect_error(
    max_speed_allometric(as_units(4, "m"), mode = "running")
  )
})

test_that("max_speed_allometric matches move2utils", {
  skip_if_not_installed("move2utils")
  speed <- max_speed_allometric(4, mode = "running")
  direct <- move2utils::v_phys_estimate(4, mode = "running")
  expect_s3_class(speed, "units")
  expect_identical(units::deparse_unit(speed), "m s-1")
  expect_equal(as.numeric(speed), as.numeric(direct))
  expect_equal(unname(attr(speed, "ci")[1, ]), attr(direct, "ci"))
  expect_identical(colnames(attr(speed, "ci")), c("lower", "upper"))
})

test_that("max_speed_allometric converts mass to kg", {
  skip_if_not_installed("move2utils")
  expect_equal(
    max_speed_allometric(as_units(4000, "g"), mode = "running"),
    max_speed_allometric(4, mode = "running")
  )
})

test_that("max_speed_allometric is vectorised over mass and mode", {
  skip_if_not_installed("move2utils")
  speed <- max_speed_allometric(c(4, 0.03), mode = c("running", "flying"))
  expect_length(speed, 2)
  expect_equal(
    as.numeric(speed),
    c(
      as.numeric(move2utils::v_phys_estimate(4, mode = "running")),
      as.numeric(move2utils::v_phys_estimate(0.03, mode = "flying"))
    )
  )
  expect_identical(dim(attr(speed, "ci")), c(2L, 2L))
  # a single mode is recycled
  expect_length(max_speed_allometric(c(4, 10), mode = "running"), 2)
})

test_that("max_speed_allometric can be used with tt_clean_mcconnell", {
  skip_if_not_installed("move2utils")
  max_speed <- max_speed_allometric(4, mode = "running")
  expect_s3_class(
    tt_clean_mcconnell(example_tt, max_speed = max_speed),
    "move2"
  )
})
