test_that("tt_hr_mcp works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_mt <- readRDS("testdata/wildboar_mt.rds")
  # error if not grouped
  expect_error(
    tt_hr_kde(boar_mt, levels = c(0.50, 0.95, 1)),
    "x must be a grouped move2 object")
  # group by name
  boar_mt <- boar_mt %>%
    dplyr::group_by(Name)
  boar_kde <- tt_hr_kde(boar_mt, levels = c(0.50, 0.95))
  # expect 8 rows
  expect_equal(nrow(boar_kde), 8)
  # expect this is an sf object
  expect_true(inherits(boar_kde, "sf"))


  # simple plotting example to check the geometry
  #  ggplot(boar_kde) +
  #    geom_sf(aes(fill=group_id), alpha = 0.7)
})
