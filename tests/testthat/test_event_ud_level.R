test_that("event_ud_level gives the correct errors", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_tt)
  expect_error(
    event_ud_level(data.frame(a = 1:10), ud),
    "x must be a move2 object"
  )
  expect_error(
    event_ud_level(example_tt, list(1)),
    "ud must be a SpatRaster or an hr_tt_ud_tbl"
  )
  ud_by_sex <- hr_tt_kde(
    dplyr::group_by(as_event_column(example_tt, "sex", .keep = TRUE), sex)
  )
  expect_error(
    event_ud_level(example_tt, ud_by_sex),
    "the first column of ud \\('sex'\\) must be a column of x"
  )
  two_layers <- c(ud$ud[[1]], ud$ud[[2]])
  names(two_layers) <- c("first", "second")
  expect_error(
    event_ud_level(example_tt, two_layers),
    "ud must have a layer named 'ud', or a single layer"
  )
})

test_that("event_ud_level matches move2utils for a single UD", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_tt)
  level <- event_ud_level(example_tt, ud$ud[["a"]])
  expect_type(level, "double")
  expect_length(level, nrow(example_tt))
  expect_equal(
    level,
    move2utils::ud_outer_probability(example_tt, ud$ud[["a"]][["ud"]])
  )
  expect_true(all(level >= 0 & level <= 1))
  # events of track a are closer to the core of its UD than other events
  in_a <- event_track_id(example_tt) == "a"
  expect_lt(mean(level[in_a]), mean(level[!in_a]))
})

test_that("event_ud_level uses the UD of each track from a table", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_tt)
  level <- event_ud_level(example_tt, ud)
  ids <- as.character(event_track_id(example_tt))
  for (id in c("a", "b", "c")) {
    expect_equal(
      level[ids == id],
      move2utils::ud_outer_probability(
        example_tt[ids == id, ],
        ud$ud[[id]][["ud"]]
      )
    )
  }
  # wrapped tables work too
  expect_equal(event_ud_level(example_tt, hr_tt_ud_wrap(ud)), level)
})

test_that("event_ud_level uses a table with a single row for all events", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_tt)
  expect_equal(
    event_ud_level(example_tt, ud[1, ]),
    event_ud_level(example_tt, ud$ud[[1]])
  )
})

test_that("event_ud_level matches events to a table by an event column", {
  skip_if_not_installed("move2utils")
  x <- as_event_column(example_tt, "sex", .keep = TRUE)
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

test_that("event_ud_level gives NA for events without a location or UD", {
  skip_if_not_installed("move2utils")
  ud <- hr_tt_kde(example_tt)
  x <- example_tt
  sf::st_geometry(x)[2] <- sf::st_point()
  level <- event_ud_level(x, ud)
  expect_true(is.na(level[2]))
  expect_equal(level[-2], event_ud_level(example_tt, ud)[-2])
  # events of a track without a UD in the table
  level_ab <- event_ud_level(example_tt, ud[1:2, ])
  expect_true(all(is.na(level_ab[event_track_id(example_tt) == "c"])))
})

test_that("event_ud_level reprojects events to the CRS of the UD", {
  skip_if_not_installed("move2utils")
  x_proj <- sf::st_transform(example_tt, "+proj=eqearth")
  ud <- hr_tt_kde(x_proj)
  expect_equal(
    event_ud_level(example_tt, ud),
    event_ud_level(x_proj, ud)
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
