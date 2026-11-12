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

test_that("hr_tt_ud_iso converts grouped tables of utilisation distributions", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  boar_kde$sex <- c("male", "female", "female", "male")
  # hr_tt_ud_sum() returns a grouped table, with one UD per group
  sex_kde <- hr_tt_ud_sum(dplyr::group_by(boar_kde, sex))
  sex_iso <- hr_tt_ud_iso(sex_kde, levels = c(0.5, 0.95))

  expect_s3_class(sex_iso, "hr_tt_poly_tbl")
  expect_equal(nrow(sex_iso), 4)
  expect_equal(sex_iso$sex, rep(c("female", "male"), each = 2))
  expect_equal(sex_iso$level, rep(c(0.5, 0.95), 2))
  # each UD gives the same isopleths as on its own
  for (i in seq_len(nrow(sex_kde))) {
    expect_equal(
      as.numeric(sex_iso$area[sex_iso$sex == sex_kde$sex[i]]),
      as.numeric(hr_tt_ud_iso(sex_kde$ud[[i]], levels = c(0.5, 0.95))$area)
    )
  }
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

test_that("hr_tt_ud_iso closes isopleths along the edges of the grid", {
  # UDs cut by the edges of the grid: a band that crosses the grid from south
  # to north, and a bump centred on its north-east corner (with more than
  # 100,000 cells, whose contours are computed on a sample of the cells)
  for (n_cells in c(100, 400)) {
    ud <- terra::rast(
      nrows = n_cells,
      ncols = n_cells,
      xmin = -50,
      xmax = 50,
      ymin = -50,
      ymax = 50,
      crs = "EPSG:32630"
    )
    xy <- terra::crds(ud)
    levels <- c(0.5, 0.95)
    for (shape in c("band", "bump")) {
      density <- switch(
        shape,
        band = exp(-(xy[, 1]^2) / (2 * 10^2)),
        bump = exp(-((xy[, 1] - 50)^2 + (xy[, 2] - 50)^2) / (2 * 20^2))
      )
      terra::values(ud) <- density / sum(density)
      names(ud) <- "ud"
      iso <- hr_tt_ud_iso(ud, levels = levels)
      expect_true(all(sf::st_is_valid(iso)))
      # the isopleths cover the area within them, up to the edges
      expected <- switch(
        shape,
        # the band is normal along x, with a standard deviation of 10, so its
        # isopleths span qnorm((1 + level) / 2) standard deviations on each
        # side of x = 0, along the 100 m of the grid (all the cells of a
        # column of the grid have the same UD, so they share their
        # cumulative UD, and the cells within an isopleth are whole columns)
        band = 2 * 10 * stats::qnorm((1 + levels) / 2) * 100,
        # the cells within the isopleths
        bump = vapply(
          levels,
          function(level) {
            sum(terra::values(hr_tt_cud(ud)) <= level) * prod(terra::res(ud))
          },
          numeric(1)
        )
      )
      expect_equal(as.numeric(iso$area), expected, tolerance = 0.02)
    }
  }
})

test_that("hr_tt_ud_iso ignores duplicated levels", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_tt_kde(boar_tt, res = 50)
  expect_equal(
    hr_tt_ud_iso(boar_kde, levels = c(0.5, 0.95, 0.5)),
    hr_tt_ud_iso(boar_kde, levels = c(0.5, 0.95))
  )
  # including when computed directly by hr_tt_kde()
  expect_equal(
    hr_tt_kde(boar_tt, res = 50, levels = c(0.5, 0.95, 0.5)),
    hr_tt_kde(boar_tt, res = 50, levels = c(0.5, 0.95))
  )
})

test_that("raster_xy_matrix and xy_matrix_values convert between layouts", {
  # a raster of 2 rows and 3 columns, filled row by row from the north-west
  r <- terra::rast(
    nrows = 2,
    ncols = 3,
    xmin = 0,
    xmax = 3,
    ymin = 0,
    ymax = 2,
    vals = c(1, 2, 3, 4, 5, 6)
  )
  m <- raster_xy_matrix(r)
  # one row per column of cells, from the west, and one column per row of
  # cells, from the south
  expect_equal(m, matrix(c(4, 5, 6, 1, 2, 3), 3, 2))
  # as grDevices::contourLines() expects it, for the centres of the cells
  lines <- grDevices::contourLines(
    x = terra::xFromCol(r, 1:3),
    y = terra::yFromRow(r, 2:1),
    z = m,
    levels = 3.5
  )
  # the contour crosses each column of cells between the centres of its
  # northern (1 to 3, at y = 1.5) and southern (4 to 6, at y = 0.5) cells,
  # where their values interpolate to 3.5
  contour <- lines[[1]]
  expect_equal(contour$y[order(contour$x)], c(2 / 3, 1, 4 / 3))
  # and back, in the order of the cells of the raster
  expect_equal(xy_matrix_values(m), c(1, 2, 3, 4, 5, 6))
  expect_equal(
    terra::values(terra::setValues(r, xy_matrix_values(m)), mat = FALSE),
    terra::values(r, mat = FALSE)
  )
})
