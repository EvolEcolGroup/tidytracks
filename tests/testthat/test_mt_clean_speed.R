test_that("mt_clean_speed works correctly",{
  # compare the output of mt_clean_speed with the output of speedfilter
  expect_true(all.equal(trip::speedfilter(trip::walrus818[1:600, ], max.speed = 1000),
            mt_clean_speed(mt_as_move2(trip::walrus818[1:600, ]), max_speed = 1000)))
})
