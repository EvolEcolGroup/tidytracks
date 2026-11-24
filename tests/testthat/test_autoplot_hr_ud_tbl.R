# a KDE needs projected data
example_proj <- sf::st_transform(example_tt, "+proj=laea +lon_0=-1 +lat_0=0")

test_that("autoplot selects the UDs of a grouped tibble", {
  # the UDs summed by sex, as a grouped tibble
  kde_by_sex <- hr_tt_kde(example_proj) %>%
    dplyr::left_join(show_meta(example_tt), by = "track_id") %>%
    dplyr::group_by(sex) %>%
    hr_tt_ud_sum()
  p <- ggplot2::autoplot(kde_by_sex, id_to_plot = "male")
  expect_length(p, 1)
  # the panel shows the UD of the males (the second group)
  expect_equal(
    ggplot2::layer_data(p[[1]])$value,
    terra::values(kde_by_sex$ud[[2]])[, 1]
  )
})

test_that("autoplot identifies the UDs by all the grouping variables", {
  # one UD per track, grouped by sex and track id: female_c, male_a, male_b
  kde <- hr_tt_kde(group_by_meta(example_proj, sex, track_id))
  p <- ggplot2::autoplot(kde, id_to_plot = "male_b")
  expect_length(p, 1)
  expect_equal(
    ggplot2::layer_data(p[[1]])$value,
    terra::values(kde$ud[[3]])[, 1]
  )
  # an id must identify a UD
  expect_error(
    ggplot2::autoplot(kde, id_to_plot = "male"),
    "all id_to_plot must be ids of the UDs"
  )
})
