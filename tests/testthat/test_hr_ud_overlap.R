test_that("hr_ud_overlap works", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde <- hr_kde(boar_tt, res = 50)
  # create the overlap
  boar_overlap <- hr_ud_overlap(boar_kde)
  # expect a 4x4 matrix
  expect_equal(dim(boar_overlap), c(4, 4))

  # test the overlap method for just two SpatRasters
  boar_overlap_2 <- hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]])
  expect_equal(boar_overlap_2, boar_overlap[1, 2])

  pairwise_overlap <- function(method, cond_level = NULL) {
    n <- nrow(boar_kde)
    result <- diag(1, n)
    for (i in seq_len(n - 1L)) {
      for (j in seq.int(i + 1L, n)) {
        result[i, j] <- result[j, i] <- hr_ud_overlap(
          boar_kde$ud[[i]],
          boar_kde$ud[[j]],
          method = method,
          cond_level = cond_level
        )
      }
    }
    rownames(result) <- colnames(result) <- boar_kde$name
    result
  }

  for (method in c("ba", "vi", "udoi")) {
    for (cond_level in list(NULL, 0.5)) {
      expect_equal(
        hr_ud_overlap(boar_kde, method = method, cond_level = cond_level),
        pairwise_overlap(method, cond_level)
      )
    }
  }

  # create a new SpatRaster with different resolution and test that it throws an
  # error
  boar_kde_diff_res <- hr_kde(boar_tt, res = 100)
  expect_error(
    hr_ud_overlap(boar_kde$ud[[1]], boar_kde_diff_res$ud[[2]]),
    "x and y must have the same geometry"
  )
  # add an extra layer to one raster and check that it still works correctly
  boar_kde_1_extra_layer <- boar_kde$ud[[1]]
  boar_kde_1_extra_layer <- c(boar_kde_1_extra_layer, boar_kde$ud[[1]])
  # rename layers so that ud is not the first layer
  names(boar_kde_1_extra_layer) <- c("extra_layer", "ud")
  boar_overlap_extra_layer <- hr_ud_overlap(
    boar_kde_1_extra_layer,
    boar_kde$ud[[2]]
  )
  expect_equal(boar_overlap_extra_layer, boar_overlap[1, 2])
  boar_kde_extra_layer <- boar_kde
  boar_kde_extra_layer$ud[[1]] <- boar_kde_1_extra_layer
  expect_equal(
    hr_ud_overlap(boar_kde_extra_layer),
    pairwise_overlap("ba")
  )
  # now rename the ud layer to something else and check that it throws an error
  names(boar_kde_1_extra_layer) <- c("extra_layer", "not_ud")
  expect_error(
    hr_ud_overlap(boar_kde_1_extra_layer, boar_kde$ud[[2]]),
    "x must have a layer named 'ud'"
  )
  # check what happens if some cells are NA in one of the rasters
  boar_kde_na <- boar_kde$ud[[1]]
  # set some cells to NA
  boar_kde_na[1:10] <- NA
  boar_overlap_na <- hr_ud_overlap(boar_kde_na, boar_kde$ud[[2]])
  # the overlap should still be a number between 0 and 1
  expect_false(is.na(boar_overlap_na))
  expect_true(boar_overlap_na >= 0 && boar_overlap_na <= 1)
  boar_kde_na_tbl <- boar_kde
  boar_kde_na_tbl$ud[[1]] <- boar_kde_na
  expect_false(is.na(hr_ud_overlap(boar_kde_na_tbl)[1, 2]))

  boar_kde_bad_geom <- boar_kde
  boar_kde_bad_geom$ud[[2]] <- boar_kde_diff_res$ud[[2]]
  expect_error(
    hr_ud_overlap(boar_kde_bad_geom),
    "all UDs must have the same geometry"
  )

  # get error if we set cond_level to a value outside of 0 and 1
  expect_error(
    hr_ud_overlap(boar_kde$ud[[1]], boar_kde$ud[[2]], cond_level = 1.5),
    "cond_level must be a single numeric value between 0 and 1"
  )
  expect_error(
    hr_ud_overlap(boar_kde, cond_level = 1.5),
    "cond_level must be a single numeric value between 0 and 1"
  )
  # error if we have more than one value for cond_level
  expect_error(
    hr_ud_overlap(
      boar_kde$ud[[1]],
      boar_kde$ud[[2]],
      cond_level = c(0.5, 0.95)
    ),
    "cond_level must be a single numeric value between 0 and 1"
  )
  # check that the overlap is smaller when we set a cond_level
  boar_overlap_cond <- hr_ud_overlap(
    boar_kde$ud[[1]],
    boar_kde$ud[[2]],
    cond_level = 0.5
  )
  expect_true(boar_overlap_cond < boar_overlap[1, 2])
})

test_that("hr_ud_overlap calculates Earth Mover's Distance when available", {
  x <- terra::rast(ncols = 3, nrows = 2, xmin = 0, xmax = 3, ymin = 0, ymax = 2)
  y <- x
  names(x) <- names(y) <- "ud"
  terra::values(x) <- c(1, 0, 0, 0, 0, 0)
  terra::values(y) <- c(0, 0, 1, 0, 0, 0)

  if (!requireNamespace("emdist", quietly = TRUE)) {
    expect_error(
      hr_ud_overlap(x, y, method = "earth_mover"),
      "requires the suggested package 'emdist'"
    )
    return()
  }

  expect_equal(hr_ud_overlap(x, y, method = "earth_mover"), 2)
  ud_tbl <- tibble::tibble(id = c("x", "y"), ud = list(x, y))
  class(ud_tbl) <- c("hr_ud_tbl", class(ud_tbl))
  expect_equal(
    hr_ud_overlap(ud_tbl, method = "earth_mover"),
    matrix(c(0, 2, 2, 0), nrow = 2, dimnames = list(c("x", "y"), c("x", "y")))
  )
})
