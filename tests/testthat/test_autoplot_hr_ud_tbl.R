test_that("autoplot selects the UDs of a grouped tibble", {
  # the UDs summed by sex, as a grouped tibble
  kde_by_sex <- hr_tt_kde(example_tt) %>%
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
