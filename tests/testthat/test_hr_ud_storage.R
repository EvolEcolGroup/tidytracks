test_that("hr_ud_wrap and hr_ud_unwrap preserve utilisation distributions", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50) %>%
    dplyr::group_by(name)

  wrapped_kde <- hr_ud_wrap(boar_kde)
  expect_s3_class(wrapped_kde, "grouped_df")
  expect_true(inherits(wrapped_kde$ud, "PackedSpatRaster_list"))
  expect_false(inherits(boar_kde$ud, "PackedSpatRaster_list"))
  expect_identical(hr_ud_wrap(wrapped_kde), wrapped_kde)

  unwrapped_kde <- hr_ud_unwrap(wrapped_kde)
  expect_s3_class(unwrapped_kde, "grouped_df")
  expect_false(inherits(unwrapped_kde$ud, "PackedSpatRaster_list"))
  expect_true(all(vapply(unwrapped_kde$ud, inherits, logical(1), "SpatRaster")))
  expect_equal(
    terra::values(unwrapped_kde$ud[[1]]),
    terra::values(boar_kde$ud[[1]])
  )
  expect_identical(hr_ud_unwrap(unwrapped_kde), unwrapped_kde)
})

test_that("UD storage helpers validate table and raster columns", {
  raster <- terra::rast(nrows = 2, ncols = 2, vals = 1:4)
  invalid_tbl <- tibble::tibble(ud = list(raster))

  expect_error(hr_ud_wrap(invalid_tbl), "x must be an hr_ud_tbl")
  expect_error(hr_ud_unwrap(invalid_tbl), "x must be an hr_ud_tbl")
})

test_that(
  "hr_ud_saveRDS writes a wrapped copy that can be used after loading",
  {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  output_file <- tempfile(fileext = ".rds")
  on.exit(unlink(output_file), add = TRUE)

  expect_silent(hr_ud_saveRDS(boar_kde, output_file))
  saved_kde <- readRDS(output_file)

  expect_s3_class(saved_kde, "hr_ud_tbl")
  expect_true(inherits(saved_kde$ud, "PackedSpatRaster_list"))
  expect_false(inherits(boar_kde$ud, "PackedSpatRaster_list"))

  expect_equal(
    as.matrix(hr_ud_sum(saved_kde)$ud[[1]]),
    as.matrix(hr_ud_sum(boar_kde)$ud[[1]])
  )
  expect_equal(
    hr_ud_overlap(saved_kde),
    hr_ud_overlap(boar_kde)
  )
  expect_equal(
    hr_ud_iso(saved_kde, levels = 0.5),
    hr_ud_iso(boar_kde, levels = 0.5)
  )
  expect_equal(length(autoplot(saved_kde)), length(autoplot(boar_kde)))

  saved_grouped <- saved_kde %>%
    dplyr::mutate(sex = c("male", "female", "female", "male")) %>%
    dplyr::group_by(sex)
  plain_grouped <- boar_kde %>%
    dplyr::mutate(sex = c("male", "female", "female", "male")) %>%
    dplyr::group_by(sex)
  expect_equal(
    lapply(hr_ud_sum(saved_grouped)$ud, terra::values),
    lapply(hr_ud_sum(plain_grouped)$ud, terra::values)
  )
  expect_true(inherits(saved_kde$ud, "PackedSpatRaster_list"))

  loaded_kde <- hr_ud_unwrap(saved_kde)
  expect_true(all(vapply(loaded_kde$ud, inherits, logical(1), "SpatRaster")))
  expect_equal(
    terra::values(loaded_kde$ud[[1]]),
    terra::values(boar_kde$ud[[1]])
  )
  }
)
