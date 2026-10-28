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

test_that("hr_tt_mcp returns the tracks of ungrouped data in metadata order", {
  # the events are in the order a, b, c, whilst the metadata is in the order
  # b, a, c
  x <- tt_order_time(
    readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  )
  track_mcp <- hr_tt_mcp(x)
  expect_equal(unique(track_mcp$track_id), c("b", "a", "c"))
  expect_equal(
    track_mcp$area[track_mcp$track_id == "b"],
    hr_tt_mcp(x[move2::mt_track_id(x) == "b", ])$area
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

test_that("hr_tt_mcp rejects missing, empty or non-numeric levels", {
  boar_tt <- readRDS(file.path(test_path("testdata"), "wildboar_tt.rds"))

  expect_error(
    hr_tt_mcp(boar_tt, levels = c(0.5, NA)),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_mcp(boar_tt, levels = numeric(0)),
    "levels must be between 0 and 1"
  )
  expect_error(
    hr_tt_mcp(boar_tt, levels = "0.5"),
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

test_that("hr_tt_mcp gives empty polygons for levels with no area", {
  # with 4 locations, the 50% MCP is the hull of the 2 locations closest to
  # the centroid: a segment, which has no area
  coords <- data.frame(id = "a", x = c(0, 1, 3, 0), y = c(0, 0, 1, 4))
  coords$time <- as.POSIXct("2024-01-01", tz = "UTC") + seq_len(4) * 60
  for (crs in c(32630, 4326)) {
    track <- move2::mt_as_move2(
      sf::st_as_sf(coords, coords = c("x", "y"), crs = crs),
      time_column = "time",
      track_id_column = "id"
    )
    track_mcp <- hr_tt_mcp(track)
    expect_equal(sf::st_is_empty(track_mcp), c(FALSE, TRUE))
    expect_equal(as.numeric(track_mcp$area) > 0, c(TRUE, FALSE))
    expect_true(all(sf::st_is_valid(track_mcp)))
  }
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
