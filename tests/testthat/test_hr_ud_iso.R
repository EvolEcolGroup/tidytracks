test_that("hr_ud_iso works", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  boar_iso <- hr_ud_iso(boar_kde, levels = c(0.5, 0.95))
  # create isopleths at 50 and 95% levels
  boar_iso <- hr_ud_iso(boar_kde, levels = c(0.50, 0.95))
  # this should be an sf object with 8 rows (4 groups x 2 levels)
  expect_equal(nrow(boar_iso), 8)
  expect_true(inherits(boar_iso, "sf"))
  # now create it directly with hr_kde
  boar_iso2 <- hr_kde(boar_tt, levels = c(0.50, 0.95), res = 50)
  # this should be the same as the previous one
  expect_equal(boar_iso, boar_iso2, ignore_attr = TRUE)
  
  # when computing isopleths, check that we get an error if we don't have 
  # a ud layer in the SpatRaster
  boar_kde_1_no_ud <- boar_kde$ud[[1]]
  names(boar_kde_1_no_ud) <- "not_ud"
  expect_error(hr_ud_iso(boar_kde_1_no_ud, levels = c(0.50, 0.95)),
               "x must have a layer named 'ud'")
})
