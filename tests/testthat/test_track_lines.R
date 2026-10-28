test_that("track_lines returns the tracks in the order of the metadata", {
  example_tt_2 <- readRDS(file.path(test_path("testdata"), "example_tt_2.rds"))
  # after ordering, the events are in the order a, b, c, whilst the metadata
  # is still in the order b, a, c
  example_tt_2 <- tt_order_time(example_tt_2)
  lines <- track_lines(example_tt_2)
  expect_equal(as.character(lines$track_id), c("b", "a", "c"))
  # each line joins the events of its track
  expect_equal(
    unname(sf::st_coordinates(lines[2, ])[, c("X", "Y")]),
    unname(sf::st_coordinates(
      example_tt_2[event_track_id(example_tt_2) == "a", ]
    ))
  )
})
