test_that("hr_ud_overlap works", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))
  boar_kde <- tt_hr_kde(boar_tt, res = 50)
  # create the overlap
  boar_overlap <- hr_ud_overlap(boar_kde)
  # expect a 4x4 matrix
  expect_equal(dim(boar_overlap), c(4, 4))
  
  # test the overlap method for just two SpatRasters
  boar_overlap_2 <- hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]])
  expect_equal(boar_overlap_2, boar_overlap[1, 2])
  
  # create a new SpatRaster with different resolution and test that it throws an
  # error
  boar_kde_diff_res <- tt_hr_kde(boar_tt, res = 100)
  expect_error(hr_ud_overlap(boar_kde$ud[[1]], boar_kde_diff_res$ud[[2]]),
               "x and y must have the same geometry")
  # add an extra layer to one raster and check that it still works correctly
  boar_kde_1_extra_layer <- boar_kde$ud[[1]]
  boar_kde_1_extra_layer <- c(boar_kde_1_extra_layer, boar_kde$ud[[1]])
  # rename layers so that ud is not the first layer
  names(boar_kde_1_extra_layer) <- c("extra_layer", "ud")
  boar_overlap_extra_layer <- hr_ud_overlap(boar_kde_1_extra_layer,
                                            boar_kde$ud[[2]])
  expect_equal(boar_overlap_extra_layer, boar_overlap[1, 2])
  # now rename the ud layer to something else and check that it throws an error
  names(boar_kde_1_extra_layer) <- c("extra_layer", "not_ud")
  expect_error(hr_ud_overlap(boar_kde_1_extra_layer, boar_kde$ud[[2]]),
               "x must have a layer named 'ud'")
})