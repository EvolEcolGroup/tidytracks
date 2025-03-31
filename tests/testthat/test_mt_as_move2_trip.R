test_that("mt_as_move2_trip work correctly",{
  test_trip <- trip::walrus818
  test_move2 <- mt_as_move2(test_trip)
  expect_true(inherits(test_move2,"move2"))
  expect_equal(nrow(test_move2),nrow(test_trip))
  # get time and id info from trip object
  trip_time_id <- trip::getTimeID(test_trip)
  # check they are the same in the move2 object
  expect_equal(move2::mt_time(test_move2),trip_time_id[,1])
  expect_equal(move2::mt_track_id(test_move2),trip_time_id[,2])
})
