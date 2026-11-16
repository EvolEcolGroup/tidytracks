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
  # with several tracks too, which adds their median if they share their radii
  two <- as_ars_move2(rbind(
    simulate_ars_track("a", 2000, n_patches = 2),
    simulate_ars_track("b", 2000, n_patches = 2, seed = 2)
  ))
  p <- ggplot2::autoplot(track_fpt_profile(two, as_units(c(1, 2, 5), "km")))
  expect_s3_class(p, "ggplot")
  expect_length(p$layers, 2)
  # but not with the default radii, which differ between the tracks
  expect_length(ggplot2::autoplot(track_fpt_profile(two))$layers, 1)
})

test_that("the default radii are chosen for each track, or group", {
  df <- rbind(
    simulate_ars_track("a", 2000, n_patches = 2),
    simulate_ars_track("b", 500, n_patches = 2, seed = 2)
  )
  df$animal <- "first"
  x <- as_ars_move2(df)
  profile <- track_fpt_profile(x)
  # from twice the median step to half the diagonal of the bounding box of
  # each track
  steps <- list()
  half_diagonals <- list()
  for (id in c("a", "b")) {
    xy <- as.matrix(df[df$id == id, c("x", "y")])
    steps[[id]] <- sqrt(rowSums(diff(xy)^2))
    extent <- apply(xy, 2, function(v) diff(range(v)))
    half_diagonals[[id]] <- sqrt(sum(extent^2)) / 2
    radii <- as.numeric(profile$radius[profile$id == id])
    expect_length(radii, 50)
    expect_equal(min(radii), 2 * stats::median(steps[[id]][steps[[id]] > 0]))
    expect_equal(max(radii), half_diagonals[[id]])
  }
  # a group pools the steps of its tracks (not across them), up to half the
  # diagonal of its largest track
  grouped <- track_fpt_profile(dplyr::group_by(x, animal))
  pooled <- unlist(steps)
  expect_equal(
    min(as.numeric(grouped$radius)),
    2 * stats::median(pooled[pooled > 0])
  )
  expect_equal(max(as.numeric(grouped$radius)), max(unlist(half_diagonals)))
  # a track too short for the default radii gets a row of missing values
  short <- data.frame(
    id = "c",
    x = 500000 + c(0, 100),
    y = 5000000,
    time = max(df$time) + c(300, 600),
    animal = "second"
  )
  expect_warning(
    with_short <- track_fpt_profile(as_ars_move2(rbind(df, short))),
    "could not be computed for c"
  )
  expect_identical(sum(with_short$id == "c"), 1L)
  expect_true(is.na(with_short$var_log_fpt[with_short$id == "c"]))
  expect_identical(with_short$n_valid[with_short$id == "c"], 0)
})
