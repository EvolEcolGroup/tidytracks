test_that("track_duration gives the correct errors", {
  # try running it on an object that isn't a move2 object
  expect_error(
    track_duration(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("track_duration correctly computes track duration", {
  expect_equal(
    unname(track_duration(example_tt, units = "hours")[1]),
    as_units(c(4 / 3), "hours")
  )
  expect_equal(
    length(track_duration(example_tt, units = "hours")),
    3
  )
})

test_that("track_duration returns values in original order", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # example_tt_2 has tracks that first appear in the order b, a, c, which
  # differs from alphabetical order
  durations <- track_duration(example_tt_2, units = "hours")

  expect_equal(names(durations), c("b", "a", "c"))
  expect_equal(
    unname(durations),
    as_units(c(5 / 3, 4 / 3, 1), "hours")
  )
})
