test_that("hr_tt_ud_sum works", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  expect_false(inherits(boar_kde$ud, "PackedSpatRaster_list"))
  rast_sum <- hr_tt_ud_sum(boar_kde$ud)
  # check that this is a raster
  expect_s4_class(rast_sum, "SpatRaster")
  # check that the sum of the raster values is 1
  expect_equal(unname(unlist(terra::global(rast_sum, sum, na.rm = TRUE))), 1)
  # check that layer is called ud
  expect_equal(names(rast_sum), "ud")

  ## now do the same directly on the tibble
  tibble_sum <- hr_tt_ud_sum(boar_kde)
  expect_equal(as.matrix(rast_sum), as.matrix(tibble_sum$ud[[1]]))

  # now test on a grouped tibble
  boar_kde$sex <- c("male", "female", "female", "male")
  boar_grouped_kde <- boar_kde %>% dplyr::group_by(sex)
  grouped_sum <- hr_tt_ud_sum(boar_grouped_kde)
  # check that this is a hr_tt_ud_tbl
  expect_true(inherits(grouped_sum, "hr_tt_ud_tbl"))
  # check that we have two rows
  expect_true(nrow(grouped_sum) == 2)
  # check that there is a column sex
  expect_true("sex" %in% names(grouped_sum))
})

test_that("hr_tt_ud_sum sums UDs estimated with different bandwidths", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50, h = "h_ref_indiv")
  tibble_sum <- hr_tt_ud_sum(boar_kde)
  expect_equal(nrow(tibble_sum), 1)
  expect_equal(
    as.matrix(tibble_sum$ud[[1]]),
    as.matrix(hr_tt_ud_sum(boar_kde$ud))
  )
  # whose sum has no single bandwidth
  expect_identical(tibble_sum$h, NA_real_)
  # but UDs on different grids cannot be summed
  expect_error(
    hr_tt_ud_sum(hr_tt_kde(boar_tt, res = c(50, 25, 50, 50))),
    "all UDs should have the same extent and resolution"
  )
})
