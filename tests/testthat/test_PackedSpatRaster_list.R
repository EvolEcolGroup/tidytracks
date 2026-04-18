test_that("PackedSpatRaster_list works with multiple rasters", {
  # example rasters
  r1 <- terra::rast(nrows = 6, ncols = 6, vals = 1:36, crs = "EPSG:4326")
  r2 <- terra::rast(nrows = 6, ncols = 6, vals = rnorm(36), crs = "EPSG:4326")
  r3 <- terra::rast(nrows = 4, ncols = 8, nlyr = 3, vals = runif(4 * 8 * 3))
  # create PackedSpatRaster_list
  pl <- PackedSpatRaster_list(a = r1, b = r2, c = r3)
  # print(pl)
  # check that it has the correct class
  expect_true(inherits(pl, "PackedSpatRaster_list"))
  # check that the accessors return a normal (unpacked) SpatRaster
  expect_true(inherits(pl[[1]], "SpatRaster"))
  expect_true(inherits(pl$b, "SpatRaster"))
  # check that accessing a null element returns NULL
  expect_null(pl$e)
  # subsetting should return a PackedSpatRaster_list
  expect_true(inherits(pl[1:2], "PackedSpatRaster_list"))
  # same if we just subset to one element
  expect_true(inherits(pl[1], "PackedSpatRaster_list"))
  # test assignment of a new element with [[]]
  pl[[4]] <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  expect_true(length(pl) == 4)
  # now assign with $
  pl$e <- terra::rast(nrows = 3, ncols = 3, vals = 9:1, crs = "EPSG:32632")
  expect_true(length(pl) == 5)
  # test that lapply works correctly
  extents <- lapply(pl, function(r) terra::ext(r))
  expect_true(inherits(extents[[1]], "SpatExtent"))
  # get a plain list of SpatRasters
  lst <- as.list(pl)
  # now this is a list of plain spatrasters
  expect_false(inherits(lst, "PackedSpatRaster_list"))
  expect_true(all(vapply(lst, class, character(1)) == "SpatRaster"))
})

test_that("PackedSpatRaster_list works with different inputs", {
  r1 <- terra::rast(nrows = 6, ncols = 6, vals = 1:36, crs = "EPSG:4326")
  r2 <- terra::rast(nrows = 6, ncols = 6, vals = rnorm(36), crs = "EPSG:4326")
  # test using one raster
  pl1 <- PackedSpatRaster_list(r1)
  expect_true(inherits(pl1, "PackedSpatRaster_list"))
  expect_true(inherits(pl1[[1]], "SpatRaster"))
  # using empty constructor
  pl2 <- PackedSpatRaster_list()
  expect_true(inherits(pl2, "PackedSpatRaster_list"))
  expect_true(length(pl2) == 0)
  # check error if we use a non-raster element
  expect_error(PackedSpatRaster_list(r1, "not a raster"))

  # access with null
  pl3 <- PackedSpatRaster_list(a = r1, b = r2)
  expect_null(pl3$nonexistent)
  expect_null(pl3[["blah"]])

  # test printing
  expect_output(print(pl3), "PackedSpatRaster_list\\[2\\]")
  expect_output(print(pl3), "\\$a <SpatRaster")
  expect_output(print(pl3), "\\$b <SpatRaster")
  # ingore additional arguments to print
  expect_warning(capture.output(print(pl3, extra_arg = TRUE)), "additional arg")

  # covert to a plain list
  lst <- as.list(pl3)
  expect_false(inherits(lst, "PackedSpatRaster_list"))
  expect_true(all(vapply(lst, class, character(1)) == "SpatRaster"))
  # warning if we use an additional argument to as.list
  expect_warning(as.list(pl3, extra_arg = TRUE), "additional arg")

  # test as_PackedSpatRaster_list
  pl4 <- as_PackedSpatRaster_list(lst)
  expect_true(inherits(pl4, "PackedSpatRaster_list"))
  # if we give it a PackedSpatRaster_list, it should just return it
  expect_identical(as_PackedSpatRaster_list(pl4), pl4)
  # if we give it a non-list, it should error
  expect_error(as_PackedSpatRaster_list("not a list"))
  # if we give it a list with non-SpatRaster elements, it should error
  expect_error(as_PackedSpatRaster_list(list(r1, "not a raster")))
})
