test_that("hr_tt_ud_iso converts a table of utilisation distributions", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  boar_iso <- hr_tt_ud_iso(boar_kde, levels = c(0.95, 0.5))

  expect_s3_class(boar_iso, "hr_tt_poly_tbl")
  expect_s3_class(boar_iso, "sf")
  expect_equal(nrow(boar_iso), nrow(boar_kde) * 2)
  expect_false("ud" %in% names(boar_iso))
  expect_true(
    all(
      c("name", "method", "level", "area", "geometry") %in%
        names(boar_iso)
    )
  )
  expect_true(all(sf::st_geometry_type(boar_iso) == "MULTIPOLYGON"))

  levels_by_track <- split(boar_iso$level, boar_iso$name)
  expect_true(all(vapply(
    levels_by_track,
    identical,
    logical(1),
    c(0.5, 0.95)
  )))
  areas_by_track <- split(as.numeric(boar_iso$area), boar_iso$name)
  expect_true(all(vapply(
    areas_by_track,
    function(area) area[1] <= area[2],
    logical(1)
  )))

  # the same isopleths (including the attributes of the sf table) as those
  # returned by hr_tt_kde() with levels
  expect_equal(
    boar_iso,
    hr_tt_kde(boar_tt, levels = c(0.5, 0.95), res = 50)
  )
})

test_that("hr_tt_ud_iso converts a single utilisation distribution", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  boar_iso <- hr_tt_ud_iso(boar_kde$ud[[1]], levels = c(0.95, 0.5))

  expect_s3_class(boar_iso, "sf")
  expect_equal(names(boar_iso), c("level", "area", "geometry"))
  expect_equal(boar_iso$level, c(0.5, 0.95))
  expect_true(all(sf::st_geometry_type(boar_iso) == "MULTIPOLYGON"))
  expect_true(all(as.numeric(boar_iso$area) > 0))
  expect_true(boar_iso$area[1] < boar_iso$area[2])
})

test_that("hr_tt_ud_iso validates input tables, raster layers, and levels", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  raster_without_ud <- boar_kde$ud[[1]]
  names(raster_without_ud) <- "not_ud"

  expect_error(
    hr_tt_ud_iso(tibble::tibble()),
    "x must have a column named 'ud'"
  )
  expect_error(
    hr_tt_ud_iso(tibble::tibble(ud = list("not a raster"))),
    "x\\$ud must be a list of SpatRaster objects"
  )
  expect_error(
    hr_tt_ud_iso(raster_without_ud),
    "x must have a layer named 'ud'"
  )
  expect_error(
    hr_tt_ud_iso(boar_kde$ud[[1]], levels = -0.1),
    "levels should be between 0 and 1"
  )
  expect_error(
    hr_tt_ud_iso(boar_kde$ud[[1]], levels = 1.1),
    "levels should be between 0 and 1"
  )
})

test_that("hr_tt_ud_iso returns empty sf when contours are unavailable", {
  uniform_ud <- terra::rast(nrows = 2, ncols = 2, vals = rep(1, 4))
  names(uniform_ud) <- "ud"

  expect_warning(
    result <- hr_tt_ud_iso(uniform_ud, levels = 0.5),
    "No isopleths could be computed"
  )
  expect_s3_class(result, "sf")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("level", "area", "geometry"))
})

test_that("hr_tt_ud_iso keeps holes in isopleths", {
  # a ring-shaped UD, with a low density in the centre
  ud <- terra::rast(
    nrows = 100,
    ncols = 100,
    xmin = -50,
    xmax = 50,
    ymin = -50,
    ymax = 50,
    crs = "EPSG:32630"
  )
  xy <- terra::crds(ud)
  dist_centre <- sqrt(xy[, 1]^2 + xy[, 2]^2)
  density <- exp(-((dist_centre - 25)^2) / (2 * 4^2))
  terra::values(ud) <- density / sum(density)
  names(ud) <- "ud"

  iso <- hr_tt_ud_iso(ud, levels = 0.5)
  # the isopleth is a single polygon with a hole
  polygons <- sf::st_geometry(iso)[[1]]
  expect_length(polygons, 1)
  expect_length(polygons[[1]], 2)
  centre <- sf::st_sfc(sf::st_point(c(0, 0)), crs = 32630)
  expect_false(sf::st_intersects(centre, iso, sparse = FALSE)[1, 1])
  # its area matches the area of the cells within the 50% isopleth
  cells_within <- sum(terra::values(hr_tt_cud(ud)) <= 0.5)
  expect_equal(
    as.numeric(iso$area),
    cells_within * prod(terra::res(ud)),
    tolerance = 0.02
  )
})
