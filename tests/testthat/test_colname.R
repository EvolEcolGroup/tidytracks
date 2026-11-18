test_that("colname_track_id and colname_time return the names of the columns", {
  expect_equal(colname_track_id(example_tt), "track_id")
  expect_equal(colname_time(example_tt), "date_time")
  # they follow the move2 object when its columns change
  toy_tt <- create_toy_tt()
  expect_equal(colname_track_id(toy_tt), "bird_id")
  expect_equal(colname_time(toy_tt), "date_time")
  # (the new track id has to be in both tables: it is added to the events
  # after the metadata, as show_meta<- removes the columns of the events that
  # are also in the metadata)
  show_meta(toy_tt)$trip_id <- show_meta(toy_tt)$bird_id
  toy_tt$trip_id <- toy_tt$bird_id
  toy_tt <- move2::mt_set_track_id_column(toy_tt, "trip_id")
  expect_equal(colname_track_id(toy_tt), "trip_id")
  # and match the values returned by the event_* functions
  expect_equal(toy_tt[[colname_track_id(toy_tt)]], event_track_id(toy_tt))
  expect_equal(toy_tt[[colname_time(toy_tt)]], event_time(toy_tt))
})

test_that("colname_track_id and colname_time need a move2 object", {
  expect_error(colname_track_id(data.frame(a = 1)), "track_id_column")
  expect_error(colname_time(data.frame(a = 1)), "time_column")
})
