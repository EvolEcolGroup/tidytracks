test_that("tt_hr_mcp works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_mt <- readRDS(file.path( test_path("testdata"),"wildboar_mt.rds"))

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
  
  # now rerun it and keep the kde objects
  boar_kde2 <- tt_hr_kde(boar_mt, levels = NULL)
  # expect just 4 rows
  expect_equal(nrow(boar_kde2), 4)
  # expect this is NOT an sf object
  expect_false(inherits(boar_kde2, "sf"))
  # expect the kde column is present
  expect_true("kde" %in% names(boar_kde2))

  # modify the grid
  
})
