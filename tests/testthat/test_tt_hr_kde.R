test_that("tt_hr_kde works with multiple tracks", {
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
  boar_iso <- hr_ud_iso(boar_kde, levels = c(0.50, 0.95))
  # this should be an sf object with 8 rows (4 groups x 2 levels)
  expect_equal(nrow(boar_iso), 8)
  expect_true(inherits(boar_iso, "sf"))
  # now create it directly with tt_hr_kde
  boar_iso2 <- tt_hr_kde(boar_tt, levels = c(0.50, 0.95), res = 50)
  # this should be the same as the previous one
  expect_equal(boar_iso, boar_iso2, ignore_attr = TRUE)
  # create the overlap
  boar_overlap <- hr_ud_overlap(boar_kde)
  # expect a 4x4 matrix
  expect_equal(dim(boar_overlap), c(4, 4))
  
  # test autoplot for the hr_ud_tbl object
  p <- autoplot(boar_kde)
  expect_true(inherits(p, "ggplot"))
  expect_true(inherits(p, "patchwork"))
  # it should have 4 elements
  expect_equal(length(p), 4)
  # plot just two plots
  p2 <- autoplot(boar_kde, id_to_plot = c(1,3))
  # it should have 2 elements
  expect_equal(length(p2), 2)
  # now plot just one
  p3 <- autoplot(boar_kde, id_to_plot = 2)
  # it should have 1 element
  expect_equal(length(p3), 1)
  
  # use a tt that is not grouped
  boar_tt2 <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))
  boar_kde2 <- tt_hr_kde(boar_tt2, res = 50)
  # this should be the same as the previous one
  expect_equal(boar_kde, boar_kde2, ignore_attr = TRUE)
  
  # simple plotting example to check the geometry
  #  ggplot(boar_kde) +
  #    geom_sf(aes(fill=group_id), alpha = 0.7)
  

  
})
