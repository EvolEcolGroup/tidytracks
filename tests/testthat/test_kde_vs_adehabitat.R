skip_if_not_installed("adehabitatHR")
skip_if_not_installed("sp")
test_that("hr_tt_kde is equivalent to adehabitatHR", {
  suppressPackageStartupMessages({
    library(sp)
    suppressMessages(library(adehabitatHR))
    library(terra)
  })
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

  brock_ade <- kernelUD(
    SpatialPoints(brock),
    h = "href",
    grid = mask_xy_grid,
    kern = "bivnorm"
  )

  ## now with tidytrack
  wildboars_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  wildboars_tt <- wildboars_tt %>% dplyr::group_by(name)
  mask_xy <- as.data.frame(my_grid)
  tt_bbox <- list(
    xmin = min(mask_xy$x) - 25,
    ymin = min(mask_xy$y) - 25,
    xmax = max(mask_xy$x) + 25,
    ymax = max(mask_xy$y) + 25
  )
  # adehabitatHR evaluates the kernel of every location at every cell
  wildboars_kde <- hr_tt_kde(
    wildboars_tt,
    levels = NULL,
    h = "h_ref_indiv",
    res = 50,
    bbox = tt_bbox,
    method = "exact"
  )
  # check that we have the same h value as adehabitat for Brock
  expect_true(brock_ade@h$h == wildboars_kde$h[1])
  # check that we have the correct grid
  expect_equal(range(terra::xFromCol(wildboars_kde$ud[[1]])), range(mask_xy$x))
  expect_equal(range(terra::yFromRow(wildboars_kde$ud[[1]])), range(mask_xy$y))
  # check that the values are similar (allowing for some differences in the
  # algorithms)
  # we first need to standardise the adehabitat values to 1
  brock_std_ud <- brock_ade$ud / sum(brock_ade$ud, na.rm = TRUE)
  expect_true(
    sum(abs(
      as.vector(terra::as.array(wildboars_kde$ud[[1]])[, , 1]) -
        brock_std_ud
    )) <
      1e-3
  )
  # the binned UD is close to it, binning the locations onto the grid
  wildboars_binned <- hr_tt_kde(
    wildboars_tt,
    levels = NULL,
    h = "h_ref_indiv",
    res = 50,
    bbox = tt_bbox
  )
  expect_true(
    sum(abs(
      as.vector(terra::as.array(wildboars_binned$ud[[1]])[, , 1]) -
        brock_std_ud
    )) <
      1e-2
  )
})

test_that("hr_tt_ud_overlap UDOI is equivalent to adehabitatHR", {
  suppressPackageStartupMessages({
    library(sp)
    suppressMessages(library(adehabitatHR))
  })
  data(puechabonsp)
  relocs <- puechabonsp$relocs

  # a grid that contains the whole UD of every animal
  res <- 100
  bbox <- c(xmin = 696000, ymin = 3155000, xmax = 704000, ymax = 3164500)
  grid <- expand.grid(
    x = seq(bbox[["xmin"]] + res / 2, bbox[["xmax"]] - res / 2, by = res),
    y = seq(bbox[["ymin"]] + res / 2, bbox[["ymax"]] - res / 2, by = res)
  )
  sp::coordinates(grid) <- ~ x + y
  sp::gridded(grid) <- TRUE
  ade_ud <- kernelUD(relocs[, 1], h = 200, grid = grid)
  ade_udoi <- kerneloverlaphr(
    ade_ud,
    method = "UDOI",
    percent = 95,
    conditional = FALSE
  )

  coords <- sp::coordinates(relocs)
  relocs_df <- data.frame(
    name = as.character(relocs$Name),
    x = coords[, 1],
    y = coords[, 2],
    time = as.POSIXct("2024-01-01", tz = "UTC") + seq_len(nrow(coords)) * 60
  )
  relocs_tt <- move2::mt_as_move2(
    sf::st_as_sf(relocs_df, coords = c("x", "y"), crs = 32631),
    time_column = "time",
    track_id_column = "name"
  )
  tt_kde <- hr_tt_kde(relocs_tt, h = 200, res = res, bbox = bbox)
  tt_udoi <- hr_tt_ud_overlap(tt_kde, method = "udoi")

  expect_equal(tt_udoi, unclass(ade_udoi), tolerance = 1e-2)
})
