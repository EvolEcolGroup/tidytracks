skip_if_not_installed("ctmm")

# fit the models and estimate the UDs once, as fitting is slow: Cilla, Gabs
# and Mvubu share an area in the south, Pepper and Toni an area in the north
x <- ctmm_example_tt(
  n = 60,
  tracks = c("Cilla", "Gabs", "Mvubu", "Pepper", "Toni")
)
show_meta(x)$herd <- c("south", "south", "south", "north", "north")
fits <- suppressMessages(ctmm_tt_fit(x, model = "ou"))
akde <- suppressMessages(hr_tt_akde(x, fits))
# the three buffalo of the south
akde_south <- dplyr::filter(akde, track %in% c("Cilla", "Gabs", "Mvubu"))

test_that("hr_tt_akde_pop estimates a population UD with pkde", {
  # pkde optimises the population bandwidth with a stochastic optimiser, so we
  # use the same seed to compare the UD with the one estimated by ctmm
  set.seed(1)
  pop <- hr_tt_akde_pop(akde_south, tracks = x, models = fits)
  expect_s3_class(pop, "hr_tt_ud_tbl")
  expect_named(
    pop,
    c(
      "method", "n_ud", "dof_area", "xmin", "ymin", "xmax", "ymax", "res",
      "ud", "ud_ctmm"
    )
  )
  expect_equal(nrow(pop), 1)
  expect_equal(pop$method, "pkde")
  expect_equal(pop$n_ud, 3)
  expect_true(inherits(pop$ud_ctmm[[1]], "UD"))
  expect_equal(terra::global(pop$ud[[1]], "sum", na.rm = TRUE)$sum, 1)
  expect_true(sf::st_crs(pop$ud[[1]]) == sf::st_crs(x))
  # the population UD is on the grid of the individual UDs
  expect_equal(pop$xmin, akde_south$xmin[1])
  expect_equal(pop$res, akde_south$res[1])
  expect_true(terra::compareGeom(pop$ud[[1]], akde_south$ud[[1]]))
  # the UD is the one estimated by ctmm (on the same grid)
  tel <- suppressMessages(mt_as_telemetry(x))
  set.seed(1)
  ctmm_pop <- ctmm::pkde(
    unname(tel[c("Cilla", "Gabs", "Mvubu")]),
    unname(akde_south$ud_ctmm),
    grid = akde_south$ud_ctmm[[1]],
    trace = FALSE
  )
  expect_equal(pop$ud_ctmm[[1]]$PDF, ctmm_pop$PDF)
  expect_equal(
    summary(pop$ud_ctmm[[1]], units = FALSE)$CI[1, "est"],
    summary(ctmm_pop, units = FALSE)$CI[1, "est"]
  )
})

test_that("hr_tt_akde_pop averages the UDs with method = 'mean'", {
  pop <- hr_tt_akde_pop(akde_south, method = "mean")
  expect_equal(pop$method, "akde_mean")
  # the average UD is the normalised sum of the UDs (up to the small
  # differences in the mass of the individual UDs within the grid, which ctmm
  # does not standardise before averaging)
  ud_sum <- hr_tt_ud_sum(akde_south)
  expect_equal(
    terra::values(pop$ud[[1]], mat = FALSE),
    terra::values(ud_sum$ud[[1]], mat = FALSE),
    tolerance = 1e-3
  )
  # considering the buffalo as the whole population reduces the uncertainty
  pop_all <- hr_tt_akde_pop(akde_south, method = "mean", sample = FALSE)
  expect_gt(pop_all$dof_area, pop$dof_area)
  # weights from a column of x
  akde_south$w <- c(10, 1, 1)
  pop_w <- hr_tt_akde_pop(akde_south, method = "mean", weights = "w")
  expect_false(isTRUE(all.equal(
    terra::values(pop_w$ud[[1]], mat = FALSE),
    terra::values(pop$ud[[1]], mat = FALSE)
  )))
})

test_that("hr_tt_akde_pop estimates a population UD for each group", {
  akde_groups <- akde %>%
    dplyr::left_join(show_meta(x), by = "track") %>%
    dplyr::group_by(herd)
  pop <- hr_tt_akde_pop(akde_groups, tracks = x, models = fits)
  expect_s3_class(pop, "hr_tt_ud_tbl")
  expect_equal(pop$herd, c("north", "south"))
  expect_equal(names(pop)[1], "herd")
  expect_equal(pop$n_ud, c(2, 3))
  for (ud in pop$ud) {
    expect_equal(terra::global(ud, "sum", na.rm = TRUE)$sum, 1)
  }
  # the population UDs are on a shared grid, so they can be compared
  expect_equal(length(unique(pop$xmin)), 1)
  expect_equal(dim(hr_tt_ud_overlap(pop)), c(2, 2))
})

test_that("hr_tt_akde_pop extends the grid to contain the population UD", {
  # pooling buffalo from two distant areas gives a very wide population UD
  # (see the Details of the documentation), which extends beyond the grid of
  # the individual UDs (we use a coarse grid to make the test fast)
  akde_coarse <- suppressMessages(hr_tt_akde(x, fits, res = 1000))
  pop <- hr_tt_akde_pop(akde_coarse, tracks = x, models = fits)
  # the grid is extended by whole cells, so it stays aligned
  expect_lt(pop$xmin, akde_coarse$xmin[1])
  expect_gt(pop$xmax, akde_coarse$xmax[1])
  shift_cells <- c(
    (pop$xmin - akde_coarse$xmin[1]) / 1000,
    (pop$ymin - akde_coarse$ymin[1]) / 1000
  )
  expect_equal(shift_cells, round(shift_cells))
  expect_equal(pop$res, 1000)
  # and it contains the population UD
  pop_tags <- terra::metags(pop$ud[[1]])
  # recent versions of terra return the tags as a data.frame
  density_sum <- if (is.data.frame(pop_tags)) {
    pop_tags$value[pop_tags$name == "density_sum"]
  } else {
    pop_tags[["density_sum"]]
  }
  expect_gt(as.numeric(density_sum), 0.999)
  expect_equal(terra::global(pop$ud[[1]], "sum", na.rm = TRUE)$sum, 1)
})

test_that("extend_bbox extends a bounding box by whole cells", {
  bbox <- c(xmin = 0, ymin = 0, xmax = 10, ymax = 10)
  expect_equal(
    extend_bbox(bbox, c(xmin = 1, ymin = 1, xmax = 9, ymax = 9), res = 2),
    bbox
  )
  expect_equal(
    extend_bbox(bbox, c(xmin = -3, ymin = 1, xmax = 9, ymax = 13), res = 2),
    c(xmin = -6, ymin = 0, xmax = 10, ymax = 16)
  )
})

test_that("bbox_union returns the bounding box containing all the others", {
  expect_equal(
    bbox_union(list(
      c(xmin = 0, ymin = 1, xmax = 5, ymax = 6),
      c(xmin = -1, ymin = 2, xmax = 4, ymax = 8)
    )),
    c(xmin = -1, ymin = 1, xmax = 5, ymax = 8)
  )
})

test_that("hr_tt_akde_pop returns isopleths with confidence intervals", {
  iso <- hr_tt_akde_pop(
    akde_south,
    tracks = x,
    models = fits,
    levels = c(0.5, 0.95)
  )
  expect_s3_class(iso, "hr_tt_poly_tbl")
  expect_equal(iso$level, c(0.5, 0.95))
  expect_false("ud_ctmm" %in% names(iso))
  expect_true(all(iso$area_low < iso$area))
  expect_true(all(iso$area < iso$area_high))
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", levels = 2),
    "levels must be"
  )
})

test_that("hr_tt_akde_pop optimises the weights of the individuals", {
  skip_on_cran()
  skip_if_not_installed("quadprog")
  pop <- hr_tt_akde_pop(akde_south, tracks = x, models = fits, weights = TRUE)
  expect_length(pop$ud_ctmm[[1]]$weights, 3)
  expect_equal(sum(pop$ud_ctmm[[1]]$weights), 1)
})

test_that("hr_tt_akde_pop checks its inputs", {
  # pkde needs the tracks and the models
  expect_error(hr_tt_akde_pop(akde_south), "provide the tracks")
  expect_error(
    hr_tt_akde_pop(akde_south, tracks = x[-1, ], models = fits),
    "Cilla have changed since the models were fitted"
  )
  expect_error(
    hr_tt_akde_pop(
      akde_south,
      tracks = x,
      models = dplyr::filter(fits, track != "Gabs")
    ),
    "no model for track\\(s\\) Gabs"
  )
  # weights
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", weights = TRUE),
    "require method = \"pkde\""
  )
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", weights = "missing"),
    "weights must be NULL"
  )
  akde_south$w <- c("a", "b", "c")
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", weights = "w"),
    "must be non-negative numbers"
  )
  # groups must have at least two UDs on the same grid
  expect_error(
    hr_tt_akde_pop(dplyr::group_by(akde, track), method = "mean"),
    "at least two UDs"
  )
  akde_moved <- akde_south
  akde_moved$xmin[1] <- akde_moved$xmin[1] - 1
  expect_error(
    hr_tt_akde_pop(akde_moved, method = "mean"),
    "must be on the same grid"
  )
  # the UDs must be estimated with hr_tt_akde()
  kde <- hr_tt_kde(x)
  expect_error(
    hr_tt_akde_pop(kde, method = "mean"),
    "estimated with hr_tt_akde"
  )
  expect_error(hr_tt_akde_pop(akde_south, sample = NA), "sample must be")
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", tolerance = 2),
    "tolerance must be"
  )
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", tolerance = NA_real_),
    "tolerance must be"
  )
  # ci_level is checked (before estimating the UDs) only if levels are given
  expect_error(
    hr_tt_akde_pop(akde_south, method = "mean", levels = 0.95, ci_level = 95),
    "ci_level must be"
  )
  # a group whose weights are all zero has no population UD, with either
  # method
  akde_zero <- akde_south
  akde_zero$w <- c(0, 0, 0)
  expect_error(
    hr_tt_akde_pop(akde_zero, method = "mean", weights = "w"),
    "must not all be zero"
  )
  expect_error(
    hr_tt_akde_pop(akde_zero, tracks = x, models = fits, weights = "w"),
    "must not all be zero"
  )
})
