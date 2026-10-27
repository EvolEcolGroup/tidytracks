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

test_that("track_duration correctly converts units", {
  durations_hours <- track_duration(example_tt, units = "hours")
  expect_equal(
    units(durations_hours)$numerator,
    "h"
  )
  # same underlying quantity, regardless of the requested units
  expect_equal(
    durations_hours,
    units::set_units(track_duration(example_tt, units = "days"), "hours")
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

test_that("track_duration returns values in the order of the metadata", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # after ordering, the events are in the order a, b, c, whilst the metadata
  # is still in the order b, a, c
  example_tt_2 <- tt_order_time(example_tt_2)
  expect_equal(
    unique(as.character(event_track_id(example_tt_2))),
    c("a", "b", "c")
  )

  durations <- track_duration(example_tt_2, units = "hours")
  expect_equal(names(durations), c("b", "a", "c"))
  expect_equal(
    unname(durations),
    as_units(c(5 / 3, 4 / 3, 1), "hours")
  )

  # so they can be added to the metadata
  show_meta(example_tt_2)$duration <- track_duration(example_tt_2, "hours")
  expect_equal(
    show_meta(example_tt_2)$duration[show_meta(example_tt_2)$track_id == "a"],
    as_units(4 / 3, "hours")
  )
})
