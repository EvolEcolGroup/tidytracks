test_that("tt_hr_mcp works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))

  # group by name
  boar_tt <- boar_tt %>%
    dplyr::group_by(Name)
  boar_kde <- tt_hr_kde(boar_tt, res = 50)
  # we expect 4 rows, one per group
  expect_equal(nrow(boar_kde), 4)
  # this should be  a hr_kde_tbl object
  expect_true(inherits(boar_kde, "hr_ud_tbl"))
  # the group_id column should have been renamed to Name
  expect_true("Name" %in% names(boar_kde))
  # create isopleths at 50 and 95% levels
  boar_iso <- hr_kde_iso(boar_kde, levels = c(0.50, 0.95))
  # this should be an sf object with 8 rows (4 groups x 2 levels)
  expect_equal(nrow(boar_iso), 8)
  expect_true(inherits(boar_iso, "sf"))
  # now create it directly with tt_hr_kde
  boar_iso2 <- tt_hr_kde(boar_tt, levels = c(0.50, 0.95), res = 50)
  # this should be the same as the previous one
  expect_equal(boar_iso, boar_iso2, ignore_attr = TRUE)
  
  # simple plotting example to check the geometry
  #  ggplot(boar_kde) +
  #    geom_sf(aes(fill=group_id), alpha = 0.7)
  

  
})
