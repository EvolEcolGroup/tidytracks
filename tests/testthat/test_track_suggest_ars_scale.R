# the radius of the peak, not its position among the radii, must be returned
test_that("fpt_peak finds the position of the selected peak", {
  v <- c(2, 3, 2, 5, 4, 4.5, 0)
  expect_identical(fpt_peak(v, "first", 1), 2L)
  expect_identical(fpt_peak(v, "max", 1), 4L)
  # the peak at position 6 rises by 0.5 and falls by 4.5, more than the others
  expect_identical(fpt_peak(v, "steep", 1), 6L)
  # with a wider window, the peak at position 2 has a higher value within it
  expect_identical(fpt_peak(v, "first", 2), 4L)
  # no peak: monotonic, too short, or with missing values around it
  expect_identical(fpt_peak(c(3, 2, 1), "first", 1), NA_integer_)
  expect_identical(fpt_peak(c(1, 2), "first", 1), NA_integer_)
  expect_identical(fpt_peak(c(1, 2, NA), "first", 1), NA_integer_)
  # missing values beyond the peak do not hide it
  expect_identical(fpt_peak(c(1, 2, 1, NA), "first", 2), 2L)
})

create_fpt_profile <- function(ids = c("b", "a")) {
  radii <- as_units(seq(5, 30, by = 5), "km")
  profile <- tibble::tibble(
    id = rep(ids, each = length(radii)),
    radius = rep(radii, times = length(ids)),
    var_log_fpt = rep(c(1, 3, 2, 4, 1, 0), times = length(ids)),
    n_valid = 10
  )
  class(profile) <- c("fpt_profile_tbl", class(profile))
  profile
}

test_that("track_suggest_ars_scale gives the correct errors", {
  profile <- create_fpt_profile()
  expect_error(track_suggest_ars_scale(data.frame(a = 1)), "move2 object")
  expect_error(track_suggest_ars_scale(profile, method = "other"))
  expect_error(track_suggest_ars_scale(profile, units = "km"), "units must be")
  expect_error(track_suggest_ars_scale(profile, peak_width = 0), "whole number")
  expect_error(
    track_suggest_ars_scale(profile, peak_width = 1.5),
    "whole number"
  )
})

test_that("track_suggest_ars_scale returns radii, named and in order", {
  profile <- create_fpt_profile()
  scales <- track_suggest_ars_scale(profile, units = as_units("km"))
  expect_s3_class(scales, "units")
  expect_identical(units::deparse_unit(scales), "km")
  expect_identical(names(scales), c("b", "a"))
  # the radius of the first peak (10 km), which is at the second position
  expect_equal(as.numeric(scales), c(10, 10))
  expect_equal(
    as.numeric(track_suggest_ars_scale(profile, method = "max")),
    c(20000, 20000)
  )
  # a track without a peak gets NA
  profile$var_log_fpt[profile$id == "a"] <- seq(6, 1)
  expect_true(is.na(track_suggest_ars_scale(profile)[["a"]]))
})

test_that("track_suggest_ars_scale recovers the scale of a simulated search", {
  radii <- as_units(seq(1, 40, by = 1), "km")
  for (patch_km in c(4, 8)) {
    scale <- track_suggest_ars_scale(
      as_ars_move2(
        simulate_ars_track("a", patch_km * 1000, n_patches = 8, seed = patch_km)
      ),
      radii = radii,
      method = "max",
      units = as_units("km")
    )
    # the peak is at the scale of the patches, within a factor of 2
    expect_gt(as.numeric(scale), patch_km / 2)
    expect_lt(as.numeric(scale), patch_km * 2)
  }
})

test_that("track_suggest_ars_scale takes a move2 object or a profile", {
  x <- sf::st_transform(example_tt, "+proj=laea +lat_0=0.75 +lon_0=0")
  radii <- as_units(c(50, 100, 150, 200), "km")
  expect_identical(
    track_suggest_ars_scale(x, radii = radii),
    track_suggest_ars_scale(track_fpt_profile(x, radii = radii))
  )
})
