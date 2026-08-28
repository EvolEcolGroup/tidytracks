test_that("hr_kde works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # group by name
  boar_tt <- boar_tt %>%
    dplyr::group_by(name)
  boar_kde <- hr_kde(boar_tt, res = 50)
  # we expect 4 rows, one per group
  expect_equal(nrow(boar_kde), 4)
  # this should be  a hr_kde_tbl object
  expect_true(inherits(boar_kde, "hr_ud_tbl"))
  # UDs are stored as live SpatRasters during analysis
  expect_false(inherits(boar_kde$ud, "PackedSpatRaster_list"))
  expect_true(all(vapply(boar_kde$ud, inherits, logical(1), "SpatRaster")))
  # the group_id column should have been renamed to "name"
  expect_true("name" %in% names(boar_kde))
  expect_equal(length(unique(boar_kde$xmin)), 1)
  expect_equal(length(unique(boar_kde$ymin)), 1)
  expect_equal(length(unique(boar_kde$xmax)), 1)
  expect_equal(length(unique(boar_kde$ymax)), 1)
  expect_equal(length(unique(boar_kde$res)), 1)

  # test autoplot for the hr_ud_tbl object
  p <- autoplot(boar_kde)
  expect_true(inherits(p, "ggplot"))
  expect_true(inherits(p, "patchwork"))
  # it should have 4 elements
  expect_equal(length(p), 4)
  # plot just two plots
  p2 <- autoplot(boar_kde, id_to_plot = c(1, 3))
  # it should have 2 elements
  expect_equal(length(p2), 2)
  # now plot just one
  p3 <- autoplot(boar_kde, id_to_plot = 2)
  # it should have 1 element
  expect_equal(length(p3), 1)

  # use a tt that is not grouped
  boar_tt2 <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_kde2 <- hr_kde(boar_tt2, res = 50)
  # this should be the same as the previous one
  # test updated to check all 4 UDs are the same, rather than just the first
  expect_equal(
    stats::setNames(lapply(boar_kde$ud, terra::values), boar_kde$name),
    stats::setNames(lapply(boar_kde2$ud, terra::values), boar_kde2$name)
  )

})

test_that("hr_kde bbox columns are always numeric (not list-cols)", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt <- boar_tt %>% dplyr::group_by(name)

  # Call with default (NULL) bbox — internally uses sf::st_bbox()
  boar_kde <- hr_kde(boar_tt, res = 50)
  expect_true(is.numeric(boar_kde$xmin))
  expect_true(is.numeric(boar_kde$xmax))
  expect_true(is.numeric(boar_kde$ymin))
  expect_true(is.numeric(boar_kde$ymax))

  # Call with bbox supplied as a named list
  ext <- sf::st_bbox(boar_tt)
  bbox_list <- list(
    xmin = unname(ext["xmin"]) - 1000,
    ymin = unname(ext["ymin"]) - 1000,
    xmax = unname(ext["xmax"]) + 1000,
    ymax = unname(ext["ymax"]) + 1000
  )
  boar_kde_list <- hr_kde(boar_tt, res = 50, bbox = bbox_list)
  expect_true(is.numeric(boar_kde_list$xmin))
  expect_true(is.numeric(boar_kde_list$xmax))
  expect_true(is.numeric(boar_kde_list$ymin))
  expect_true(is.numeric(boar_kde_list$ymax))
})

test_that("hr_kde accepts a separate grid for each group", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds")) %>%
    dplyr::group_by(name)
  group_names <- dplyr::group_keys(boar_tt)$name
  bbox <- lapply(seq_along(group_names), function(i) {
    c(
      xmin = i * 1000,
      ymin = i * 2000,
      xmax = i * 1000 + 500,
      ymax = i * 2000 + 1000
    )
  })

  boar_kde <- hr_kde(boar_tt, bbox = bbox, res = c(25, 50, 100, 125))

  expect_equal(boar_kde$xmin, c(1000, 2000, 3000, 4000))
  expect_equal(boar_kde$xmax, c(1500, 2500, 3500, 4500))
  expect_equal(boar_kde$res, c(25, 50, 100, 125))
  expect_equal(
    unname(vapply(boar_kde$ud, terra::ncell, numeric(1))),
    c(800, 200, 50, 32)
  )
})

test_that("hr_kde validates a collection of group-specific grids", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds")) %>%
    dplyr::group_by(name)
  bbox <- list(c(xmin = 0, ymin = 0, xmax = 100, ymax = 100))

  expect_error(
    hr_kde(boar_tt, bbox = bbox, res = 10),
    "one named vector per group"
  )
  expect_error(
    hr_kde(boar_tt, bbox = rep(bbox, 4), res = c(10, 10)),
    "one value per group"
  )
})
