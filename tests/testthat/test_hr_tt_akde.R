skip_if_not_installed("ctmm")

# fit the models once, as fitting is slow
x <- ctmm_example_tt(n = 100)
fits <- suppressMessages(ctmm_tt_fit(x, model = "ou"))

test_that("hr_tt_akde returns a table of UDs on a shared grid", {
  akde <- hr_tt_akde(x, fits)
  expect_s3_class(akde, "hr_tt_ud_tbl")
  expect_named(
    akde,
    c(
      "track", "method", "model_name", "dof_area", "xmin", "ymin", "xmax",
      "ymax", "res", "ud", "ud_ctmm"
    )
  )
  expect_equal(akde$track, c("Cilla", "Gabs"))
  expect_equal(akde$method, c("akde", "akde"))
  expect_equal(akde$model_name, fits$model_name)
  expect_true(all(vapply(akde$ud, inherits, logical(1), "SpatRaster")))
  expect_true(all(vapply(akde$ud_ctmm, inherits, logical(1), "UD")))
  # each UD sums to 1
  for (ud in akde$ud) {
    expect_equal(terra::global(ud, "sum", na.rm = TRUE)$sum, 1)
  }
  # the grid is shared
  expect_equal(length(unique(akde$xmin)), 1)
  expect_equal(length(unique(akde$res)), 1)
  expect_true(terra::compareGeom(akde$ud[[1]], akde$ud[[2]]))
  # the grid has square cells
  expect_equal(terra::res(akde$ud[[1]]), rep(akde$res[1], 2))
  # the raster is in the CRS of x
  expect_true(sf::st_crs(akde$ud[[1]]) == sf::st_crs(x))
})

test_that("hr_tt_akde UDs are those estimated by ctmm", {
  akde <- hr_tt_akde(x, fits)
  # the raster of the ctmm UD (built by ctmm) has the same values
  ctmm_rast <- terra::rast(ctmm::raster(akde$ud_ctmm[[1]], DF = "PMF"))
  expect_equal(
    terra::values(akde$ud[[1]], mat = FALSE),
    terra::values(ctmm_rast, mat = FALSE) /
      sum(terra::values(ctmm_rast, mat = FALSE)),
    ignore_attr = TRUE
  )
  expect_equal(
    as.vector(terra::ext(akde$ud[[1]])),
    as.vector(terra::ext(ctmm_rast))
  )
  # the default grid is similar to the default of ctmm, and gives the same
  # estimate of the home range area
  tel <- suppressMessages(mt_as_telemetry(x))
  ud_default <- ctmm::akde(tel$Cilla, fits$model$Cilla)
  expect_equal(akde$res[1], min(ud_default$dr), tolerance = 0.1)
  expect_equal(
    summary(akde$ud_ctmm[[1]], units = FALSE)$CI[1, "est"],
    summary(ud_default, units = FALSE)$CI[1, "est"],
    tolerance = 0.01
  )
})

test_that("hr_tt_akde uses the grid it is given", {
  bbox <- c(xmin = 20000, ymin = -15000, xmax = 60000, ymax = 15000)
  akde <- hr_tt_akde(x, fits, bbox = bbox, res = 500)
  expect_equal(unique(akde$res), 500)
  expect_equal(
    as.vector(terra::ext(akde$ud[[1]])),
    c(xmin = 20000, xmax = 60000, ymin = -15000, ymax = 15000)
  )
  expect_equal(dim(akde$ud[[2]])[1:2], c(60, 80))
  # one grid per group
  bbox_list <- list(
    c(xmin = 25000, ymin = -10000, xmax = 50000, ymax = 10000),
    c(xmin = 30000, ymin = -10000, xmax = 55000, ymax = 10000)
  )
  akde <- hr_tt_akde(x, fits, bbox = bbox_list, res = 250)
  expect_equal(akde$xmin, c(25000, 30000))
  # a grid that is too small gives a warning
  small_bbox <- c(xmin = 35000, ymin = -2000, xmax = 40000, ymax = 2000)
  expect_warning(
    hr_tt_akde(
      filter_by_meta(x, track == "Cilla"),
      fits,
      bbox = small_bbox,
      res = 100
    ),
    "the grid of group Cilla only contains"
  )
  expect_error(hr_tt_akde(x, fits, res = c(1, 2, 3)), "res must be")
  expect_error(hr_tt_akde(x, fits, res = -1), "finite, positive")
})

test_that("hr_tt_akde returns isopleths with confidence intervals", {
  iso <- hr_tt_akde(x, fits, levels = c(0.5, 0.95))
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_s3_class(iso, "sf")
  expect_equal(nrow(iso), 4)
  expect_equal(iso$level, c(0.5, 0.95, 0.5, 0.95))
  expect_false("ud_ctmm" %in% names(iso))
  expect_true(all(c("area", "area_low", "area_high") %in% names(iso)))
  expect_true(all(iso$area_low < iso$area))
  expect_true(all(iso$area < iso$area_high))
  # the area of the polygons is close to the estimate of ctmm
  akde <- hr_tt_akde(x, fits)
  ctmm_area <- summary(akde$ud_ctmm[[1]], level.UD = 0.95, units = FALSE)$CI
  expect_equal(
    as.numeric(iso$area[2]),
    ctmm_area[1, "est"],
    tolerance = 0.05
  )
  expect_error(hr_tt_akde(x, fits, levels = 2), "levels must be")
})

test_that("hr_tt_ud_iso adds the confidence intervals to AKDE isopleths", {
  akde <- hr_tt_akde(x, fits)
  iso <- hr_tt_ud_iso(akde, levels = c(0.5, 0.95))
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_false("ud_ctmm" %in% names(iso))
  expect_equal(
    names(iso)[names(iso) %in% c("area", "area_low", "area_high")],
    c("area", "area_low", "area_high")
  )
  # the same isopleths as estimating them directly with hr_tt_akde()
  expect_equal(
    iso,
    hr_tt_akde(x, fits, levels = c(0.5, 0.95)),
    ignore_attr = TRUE
  )
  # wider intervals with a higher confidence level
  iso_99 <- hr_tt_ud_iso(akde, levels = c(0.5, 0.95), ci_level = 0.99)
  expect_equal(iso_99$area, iso$area)
  expect_true(all(iso_99$area_low < iso$area_low))
  expect_true(all(iso_99$area_high > iso$area_high))
  expect_error(
    hr_tt_ud_iso(akde, levels = 0.95, ci_level = 1),
    "ci_level must be"
  )
})

test_that("hr_tt_akde UDs work with the other hr_tt_ functions", {
  akde <- hr_tt_akde(x, fits)
  iso <- hr_tt_ud_iso(akde, levels = 0.95)
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_false("ud_ctmm" %in% names(iso))
  overlap <- hr_tt_ud_overlap(akde)
  expect_equal(dim(overlap), c(2, 2))
  ud_sum <- hr_tt_ud_sum(akde)
  expect_equal(terra::global(ud_sum$ud[[1]], "sum", na.rm = TRUE)$sum, 1)
  file <- tempfile(fileext = ".rds")
  hr_tt_ud_saveRDS(akde, file)
  loaded <- readRDS(file)
  expect_equal(
    terra::values(hr_tt_ud_unwrap(loaded)$ud[[1]]),
    terra::values(akde$ud[[1]])
  )
  expect_s3_class(ggplot2::autoplot(akde), "patchwork")
})

test_that("hr_tt_akde matches the models to the tracks", {
  # a subset of the tracks
  akde <- suppressMessages(
    hr_tt_akde(filter_by_meta(x, track == "Gabs"), fits)
  )
  expect_equal(akde$track, "Gabs")
  # the models must include all tracks
  expect_error(
    hr_tt_akde(x, dplyr::filter(fits, track == "Gabs")),
    "no model for track\\(s\\) Cilla"
  )
  # the tracks must not have changed since fitting
  expect_error(
    hr_tt_akde(x[-1, ], fits),
    "Cilla have changed since the models were fitted"
  )
  # models without a home range cannot be used
  fits_bm <- fits
  fits_bm$model[[1]] <- suppressMessages(
    ctmm_tt_fit(filter_by_meta(x, track == "Cilla"), model = "bm")
  )$model[[1]]
  expect_error(hr_tt_akde(x, fits_bm), "has no home range")
  # models that could not be fitted
  fits_null <- fits
  fits_null$model[1] <- list(NULL)
  expect_error(hr_tt_akde(x, fits_null), "could not be fitted")
})

test_that("hr_tt_akde checks its inputs", {
  expect_error(hr_tt_akde(as.data.frame(x), fits), "must be a move2 object")
  expect_error(hr_tt_akde(x, tibble::tibble()), "created with ctmm_tt_fit")
  expect_error(
    hr_tt_akde(sf::st_transform(x, 32736), fits),
    "same coordinate reference system"
  )
  # groups must contain a single track
  x$herd <- "a"
  expect_error(
    hr_tt_akde(dplyr::group_by(x, herd), fits),
    "must contain a single track"
  )
  # and tracks must be in a single group
  x$period <- rep(c("a", "b"), length.out = nrow(x))
  expect_error(
    hr_tt_akde(dplyr::group_by(x, track, period), fits),
    "each track must be in a single group"
  )
  # grouping by a variable that is constant within tracks is fine
  akde <- suppressMessages(
    hr_tt_akde(dplyr::group_by(x, track, herd), fits)
  )
  expect_equal(akde$group_id, c("Cilla_a", "Gabs_a"))
})
