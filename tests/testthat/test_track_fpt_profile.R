test_that("track_fpt_profile gives the correct errors", {
  expect_error(track_fpt_profile(data.frame(a = 1)), "must be a move2 object")
  expect_error(track_fpt_profile(example_tt), "must be in a projected")
  x <- as_ars_move2(simulate_ars_track("a", 2000, n_patches = 2))
  expect_error(track_fpt_profile(x, radii = 1000), "must be a units object")
})

test_that("track_fpt_profile returns one row per track and radius", {
  df <- rbind(
    simulate_ars_track("b", 2000, n_patches = 2),
    simulate_ars_track("a", 2000, n_patches = 2, seed = 2)
  )
  x <- as_ars_move2(df)
  radii <- as_units(c(2, 1, 5), "km")
  profile <- track_fpt_profile(x, radii = radii)
  expect_s3_class(profile, "fpt_profile_tbl")
  expect_named(profile, c("id", "radius", "var_log_fpt", "n_valid"))
  expect_identical(nrow(profile), 6L)
  # in the order of the tracks in the metadata, with sorted radii in their units
  expect_identical(
    unique(profile$id),
    as.character(show_meta(x)$id)
  )
  expect_identical(units::deparse_unit(profile$radius), "km")
  expect_equal(as.numeric(profile$radius), rep(c(1, 2, 5), 2))

  # it is the variance of the log of the FPT of the events
  a <- x[event_track_id(x) == "a", ]
  fpt <- as.numeric(event_fpt(a, as_units(2, "km"), units = as_units("s")))
  row <- profile$id == "a" & as.numeric(profile$radius) == 2
  expect_equal(profile$var_log_fpt[row], stats::var(log(fpt), na.rm = TRUE))
  expect_identical(profile$n_valid[row], as.numeric(sum(!is.na(fpt))))
})

test_that("groups pool the log FPT of their tracks, computed within tracks", {
  df <- rbind(
    simulate_ars_track("a", 2000, n_patches = 2),
    simulate_ars_track("b", 2000, n_patches = 2, seed = 2),
    simulate_ars_track("c", 2000, n_patches = 2, seed = 3)
  )
  df$animal <- ifelse(df$id == "c", "second", "first")
  x <- as_ars_move2(df)
  radii <- as_units(c(1, 2, 5), "km")
  profile <- track_fpt_profile(dplyr::group_by(x, animal), radii = radii)
  expect_named(profile, c("animal", "radius", "var_log_fpt", "n_valid"))
  expect_identical(unique(profile$animal), c("first", "second"))
  # with a large radius, FPTs that ran across the tracks would differ
  fpt <- as.numeric(event_fpt(x, as_units(5, "km"), units = as_units("s")))
  row <- profile$animal == "first" & as.numeric(profile$radius) == 5
  expect_equal(
    profile$var_log_fpt[row],
    stats::var(log(fpt[df$animal == "first"]), na.rm = TRUE)
  )
})

test_that("track_fpt_profile has default radii, and a plot", {
  x <- as_ars_move2(simulate_ars_track("a", 2000, n_patches = 2))
  profile <- track_fpt_profile(x)
  expect_identical(nrow(profile), 50L)
  expect_identical(units::deparse_unit(profile$radius), "m")
  expect_false(is.unsorted(as.numeric(profile$radius)))
  p <- ggplot2::autoplot(profile)
  expect_s3_class(p, "ggplot")
  # with several tracks too, which adds their median
  two <- as_ars_move2(rbind(
    simulate_ars_track("a", 2000, n_patches = 2),
    simulate_ars_track("b", 2000, n_patches = 2, seed = 2)
  ))
  expect_s3_class(
    ggplot2::autoplot(track_fpt_profile(two, as_units(c(1, 2, 5), "km"))),
    "ggplot"
  )
})
