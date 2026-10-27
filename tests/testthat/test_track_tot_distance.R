test_that("track_tot_distance gives the correct errors", {
  # try running it on an object that isn't a move2 object
  expect_error(
    track_tot_distance(x = data.frame(a = 1:10, b = 11:20)),
    "x must be a move2 object"
  )
})

test_that("track_tot_distance correctly computes track distance", {
  expect_equal(
    track_tot_distance(example_tt),
    as_units(c(a = 1170506.6, b = 870617.4, c = 812657.4), "m"),
    tolerance = 1e-6
  )
})

test_that("track_tot_distance correctly converts units", {
  distances_km <- track_tot_distance(example_tt, units = "km")
  expect_equal(
    units(distances_km)$numerator,
    "km"
  )
  expect_equal(
    unname(distances_km),
    as_units(c(1170.5066, 870.6174, 812.6574), "km"),
    tolerance = 1e-6
  )
  # same underlying quantity, regardless of the requested units
  expect_equal(
    distances_km,
    units::set_units(track_tot_distance(example_tt), "km")
  )
})

test_that("track_tot_distance returns values in original order", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # example_tt_2 has tracks that first appear in the order b, a, c, which
  # differs from alphabetical order
  distances <- track_tot_distance(example_tt_2)
  expect_equal(names(distances), c("b", "a", "c"))
  expect_equal(
    unname(distances),
    as_units(c(1559776.1, 870617.4, 474273.1), "m"),
    tolerance = 1e-6
  )
})
