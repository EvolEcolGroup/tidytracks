test_that("hr_tt_mcp works with multiple tracks", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_mcp <- hr_tt_mcp(boar_tt)

  expect_s3_class(boar_mcp, "hr_tt_poly_tbl")
  expect_s3_class(boar_mcp, "sf")
  expect_equal(attr(boar_mcp, "hr_tt_method"), "mcp")
  expect_true(
    all(
      c("name", "method", "level", "area", "geometry") %in%
        names(boar_mcp)
    )
  )
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

test_that("hr_tt_mcp respects explicit grouping", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  grouped_mcp <- boar_tt |>
    dplyr::group_by(name) |>
    hr_tt_mcp(levels = c(0.5, 0.95))
  default_mcp <- hr_tt_mcp(boar_tt, levels = c(0.5, 0.95))

  expect_equal(grouped_mcp, default_mcp)
})

test_that("hr_tt_mcp returns the groups in the order of the group keys", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # the groups are sorted in the reverse order of the tracks in the data
  boar_tt$group <- factor(boar_tt$name, levels = rev(levels(boar_tt$name)))
  grouped_mcp <- hr_tt_mcp(dplyr::group_by(boar_tt, group))

  expect_equal(unique(grouped_mcp$group), rev(levels(boar_tt$name)))
  expect_equal(
    grouped_mcp$area[grouped_mcp$group == "Jean"],
    hr_tt_mcp(boar_tt[boar_tt$name == "Jean", ])$area
  )
})

test_that("hr_tt_mcp rejects levels outside the unit interval", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))

  expect_error(
    hr_tt_mcp(boar_tt, levels = -0.1),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_mcp(boar_tt, levels = 1.1),
    "levels must be between 0 and 1"
  )
})

test_that("hr_tt_mcp ignores events without a location", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  boar_tt_empty <- boar_tt
  sf::st_geometry(boar_tt_empty)[5] <- sf::st_point()

  expect_equal(hr_tt_mcp(boar_tt_empty), hr_tt_mcp(boar_tt[-5, ]))
})

test_that("hr_tt_mcp requires at least 3 locations per group", {
  set.seed(3)
  coords <- data.frame(
    id = c(rep("a", 10), "b", "b"),
    x = c(stats::rnorm(10), 0, 1),
    y = c(stats::rnorm(10), 0, 1)
  )
  coords$time <- as.POSIXct("2024-01-01", tz = "UTC") +
    seq_len(nrow(coords)) * 60
  tracks <- move2::mt_as_move2(
    sf::st_as_sf(coords, coords = c("x", "y"), crs = 32630),
    time_column = "time",
    track_id_column = "id"
  )

  expect_error(
    hr_tt_mcp(tracks),
    "at least 3 events with a location.*: b$"
  )
  expect_s3_class(hr_tt_mcp(tracks[tracks$id == "a", ]), "hr_tt_poly_tbl")
})

test_that("hr_tt_mcp rejects groups without events", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))
  # a grouping factor with an unused level, kept as a group with .drop = FALSE
  boar_tt$group <- factor(
    as.character(boar_tt$name),
    levels = c("unused", levels(boar_tt$name))
  )
  boar_grouped <- dplyr::group_by(boar_tt, group, .drop = FALSE)
  expect_error(
    hr_tt_mcp(boar_grouped),
    "groups without events \\(unused\\).*group_by\\(x, group, .drop = TRUE\\)"
  )
  # the suggested regrouping removes them
  expect_equal(
    hr_tt_mcp(dplyr::group_by(boar_grouped, group, .drop = TRUE)),
    hr_tt_mcp(dplyr::group_by(boar_tt, group))
  )

  # a group with events, but none with a location, is a different error
  first_track <- boar_tt$name == boar_tt$name[1]
  sf::st_geometry(boar_tt)[first_track] <- sf::st_point()
  expect_error(
    hr_tt_mcp(dplyr::group_by(boar_tt, group)),
    paste0("groups with fewer locations: ", as.character(boar_tt$name[1]), "$")
  )
})
