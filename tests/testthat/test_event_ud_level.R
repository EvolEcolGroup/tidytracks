# a KDE needs projected data
example_proj <- sf::st_transform(example_tt, "+proj=laea +lon_0=-1 +lat_0=0")

test_that("event_ud_level gives the correct errors", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  expect_error(
    event_ud_level(data.frame(a = 1:10), ud),
    "x must be a move2 object"
  )
  expect_error(
    event_ud_level(example_proj, list(1)),
    "ud must be a SpatRaster or an hr_tt_ud_tbl"
  )
  ud_by_sex <- hr_tt_kde(
    dplyr::group_by(as_event_column(example_proj, "sex"), sex)
  )
  expect_error(
    event_ud_level(example_proj, ud_by_sex),
    "identify the UDs of ud \\('sex'\\) must be columns of x"
  )
  two_layers <- c(ud$ud[[1]], ud$ud[[2]])
  names(two_layers) <- c("first", "second")
  expect_error(
    event_ud_level(example_proj, two_layers),
    "ud must have a layer named 'ud', or a single layer"
  )
})

test_that("event_ud_level matches move2utils for a single UD", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  level <- event_ud_level(example_proj, ud$ud[["a"]])
  expect_type(level, "double")
  expect_length(level, nrow(example_proj))
  expect_equal(
    level,
    move2utils::ud_outer_probability(example_proj, ud$ud[["a"]][["ud"]])
  )
  expect_true(all(level >= 0 & level <= 1))
  # events of track a are closer to the core of its UD than other events
  in_a <- event_track_id(example_proj) == "a"
  expect_lt(mean(level[in_a]), mean(level[!in_a]))
})

test_that("event_ud_level uses the UD of each track from a table", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  level <- event_ud_level(example_proj, ud)
  ids <- as.character(event_track_id(example_proj))
  for (id in c("a", "b", "c")) {
    expect_equal(
      level[ids == id],
      move2utils::ud_outer_probability(
        example_proj[ids == id, ],
        ud$ud[[id]][["ud"]]
      )
    )
  }
  # wrapped tables work too
  expect_equal(event_ud_level(example_proj, hr_tt_ud_wrap(ud)), level)
})

test_that("event_ud_level uses a table with a single row for all events", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  expect_equal(
    event_ud_level(example_proj, ud[1, ]),
    event_ud_level(example_proj, ud$ud[[1]])
  )
})

test_that("event_ud_level matches events to a table by an event column", {
  skip_if_not_installed("move2utils")
  x <- as_event_column(example_proj, "sex")
  ud_by_sex <- hr_tt_kde(dplyr::group_by(x, sex))
  level <- event_ud_level(x, ud_by_sex)
  males <- x$sex == "male"
  expect_equal(
    level[males],
    event_ud_level(x[males, ], ud_by_sex$ud[["male"]])
  )
  expect_equal(
    level[!males],
    event_ud_level(x[!males, ], ud_by_sex$ud[["female"]])
  )
})

test_that("event_ud_level matches events to a table by several columns", {
  skip_if_not_installed("move2utils")
  # one UD per track, grouped by sex and track id (in the order female_c,
  # male_a, male_b, rather than that of the tracks)
  x <- group_by_meta(example_proj, sex, track_id)
  ud <- hr_tt_kde(x)
  expect_equal(names(ud)[1:3], c("sex", "track_id", "method"))
  expect_equal(
    event_ud_level(x, ud),
    event_ud_level(x, hr_tt_kde(example_proj))
  )
})

test_that("event_ud_level matches events to a table by an sfc column", {
  skip_if_not_installed("move2utils")
  # one UD per colony, each with a single track
  x <- group_by_meta(
    sf::st_transform(create_toy_tt_geo(), 3857),
    colony_sf
  )
  ud <- hr_tt_kde(x)
  expect_s3_class(ud$colony_sf, "sfc")
  level <- event_ud_level(x, ud)
  north <- sf::st_coordinates(x$colony_sf)[, "Y"] > 30
  expect_equal(level[north], event_ud_level(x[north, ], ud$ud[[2]]))
  expect_equal(level[!north], event_ud_level(x[!north, ], ud$ud[[1]]))
})

test_that("event_ud_level gives NA for events without a location or UD", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  x <- example_proj
  sf::st_geometry(x)[2] <- sf::st_point()
  level <- event_ud_level(x, ud)
  expect_true(is.na(level[2]))
  expect_equal(level[-2], event_ud_level(example_proj, ud)[-2])
  # events of a track without a UD in the table
  level_ab <- event_ud_level(example_proj, ud[1:2, ])
  expect_true(all(is.na(level_ab[event_track_id(example_proj) == "c"])))
})

test_that("event_ud_level reprojects events to the CRS of the UD", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_proj)
  expect_equal(
    event_ud_level(example_tt, ud),
    event_ud_level(example_proj, ud)
  )
})

test_that("event_ud_level gives levels no larger than 1", {
  skip_if_not_installed("move2utils")
  x <- example_tt[1, ]
  xy <- sf::st_coordinates(x)
  # a UD of 2 x 3 cells, with the event in its least dense cell (the top
  # right one), the last of the cumulative sum of the UD, which exceeds 1 by
  # rounding (as it can for any UD on Apple silicon, where R has no extended
  # precision)
  ud <- terra::rast(
    nrows = 2,
    ncols = 3,
    xmin = xy[1] - 2.5,
    xmax = xy[1] + 0.5,
    ymin = xy[2] - 1.5,
    ymax = xy[2] + 0.5,
    crs = "EPSG:4326",
    vals = c(0.6, 0.9, 0.5, 0.9, 0.6, 0.6),
    names = "ud"
  )
  level <- event_ud_level(x, ud)
  expect_lte(level, 1)
  expect_equal(level, 1)
})
