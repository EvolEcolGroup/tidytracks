test_that("hr_mcp works with multiple tracks", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_mcp <- hr_mcp(boar_tt)

  expect_s3_class(boar_mcp, "hr_poly_tbl")
  expect_s3_class(boar_mcp, "sf")
  expect_equal(attr(boar_mcp, "hr_method"), "mcp")
  expect_true(all(c("name", "method", "level", "area", "geometry") %in%
                    names(boar_mcp)))
  expect_equal(nrow(boar_mcp), 8)
  expect_equal(boar_mcp$method, rep("mcp", nrow(boar_mcp)))
  expect_true(all(sf::st_geometry_type(boar_mcp) == "POLYGON"))

  levels_by_track <- split(boar_mcp$level, boar_mcp$name)
  expect_true(all(vapply(
    levels_by_track,
    identical,
    logical(1),
    c(0.95, 0.5)
  )))

  areas_by_track <- split(as.numeric(boar_mcp$area), boar_mcp$name)
  expect_true(all(vapply(
    areas_by_track,
    function(area) area[1] >= area[2],
    logical(1)
  )))
})

test_that("hr_mcp respects explicit grouping", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  grouped_mcp <- boar_tt |>
    dplyr::group_by(name) |>
    hr_mcp(levels = c(0.5, 0.95))
  default_mcp <- hr_mcp(boar_tt, levels = c(0.5, 0.95))

  expect_equal(grouped_mcp, default_mcp)
})

test_that("hr_mcp rejects levels outside the unit interval", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))

  expect_error(hr_mcp(boar_tt, levels = -0.1), "levels must be between 0 and 1")
  expect_error(hr_mcp(boar_tt, levels = 1.1), "levels must be between 0 and 1")
})
