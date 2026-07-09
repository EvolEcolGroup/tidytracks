test_that("hr_ud_overlap works", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  # create the overlap
  boar_overlap <- hr_ud_overlap(boar_kde)
  # expect a 4x4 matrix
  expect_equal(dim(boar_overlap), c(4, 4))
  
  # test the overlap method for just two SpatRasters
  boar_overlap_2 <- hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]])
  expect_equal(boar_overlap_2, boar_overlap[1, 2])
  
  # create a new SpatRaster with different resolution and test that it throws an
  # error
  boar_kde_diff_res <- hr_kde(boar_tt, res = 100)
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
  # check what happens if some cells are NA in one of the rasters
  boar_kde_na <- boar_kde$ud[[1]]
  # set some cells to NA
  boar_kde_na[1:10] <- NA
  boar_overlap_na <- hr_ud_overlap(boar_kde_na, boar_kde$ud[[2]])
  # the overlap should still be a number between 0 and 1
  expect_false(is.na(boar_overlap_na))
  expect_true(boar_overlap_na >= 0 && boar_overlap_na <= 1)
  
  # get error if we set cond_level to a value outside of 0 and 1
  expect_error(hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]],
                             cond_level = 1.5),
               "cond_level must be a single numeric value between 0 and 1")
  # error if we have more than one value for cond_level
  expect_error(hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]],
                             cond_level = c(0.5, 0.95)),
               "cond_level must be a single numeric value between 0 and 1")
  # check that the overlap is smaller when we set a cond_level
  boar_overlap_cond <- hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]],
                                     cond_level = 0.5)
  expect_true(boar_overlap_cond < boar_overlap[1, 2])
  
})
  
