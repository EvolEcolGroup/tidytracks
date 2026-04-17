skip_if_not_installed("adehabitatHR")
skip_if_not_installed("sp")
test_that("tt_hr_kde is equivalent to adehabitatHR", {
  library(adehabitatHR)
  library(terra)
  library(sp)
  data(puechabonsp)

  brock <- as.data.frame(puechabonsp$relocs) %>%
    dplyr::filter(Name == "Brock") %>%
    dplyr::select(x = X, y = Y)

  # this grid to be used in both
  my_grid <- expand.grid(
    x = seq(697000, 701950, by = 50),
    y = seq(3158550, 3163500, by = 50)
  )


  mask_xy_grid <- my_grid
  sp::coordinates(mask_xy_grid) <- ~ x + y
  sp::gridded(mask_xy_grid) <- TRUE

  brock_ade <- kernelUD(SpatialPoints(brock),
    h = "href",
    grid = mask_xy_grid,
    kern = "bivnorm"
  )

  # plot(brock_ade)
  ## now with tidytrack
  wildboars_tt <- readRDS(file.path( test_path("testdata"),"wildboar_tt.rds"))
  wildboars_tt <- wildboars_tt %>% dplyr::group_by(Name)
  mask.xy <- as.data.frame(my_grid)
  wildboars_kde <- tt_hr_kde(wildboars_tt,
    levels = NULL,
    h = "h_ref_indiv",
    res = 50,
    bbox = list(
      xmin = min(mask.xy$x) - 25, ymin = min(mask.xy$y) - 25,
      xmax = max(mask.xy$x) + 25, ymax = max(mask.xy$y) + 25
    )
  )
  # check that we have the same h value as adehabitat for Brock
  expect_true(brock_ade@h$h == wildboars_kde$h[1])
  # check that we have the correct grid
  expect_equal(range(terra::xFromCol(wildboars_kde$ud[[1]])), range(mask.xy$x))
  expect_equal(range(terra::yFromRow(wildboars_kde$ud[[1]])), range(mask.xy$y))
  # check that the values are similar (allowing for some differences in the
  # algorithms)
  # we first need to standardise the adehabitat values to 1
  brock_std_ud <- brock_ade$ud / sum(brock_ade$ud, na.rm = TRUE)
  expect_true(sum(abs(as.vector(terra::as.array(wildboars_kde$ud[[1]])[, , 1]) -
    brock_std_ud)) < 1e-3)
})
