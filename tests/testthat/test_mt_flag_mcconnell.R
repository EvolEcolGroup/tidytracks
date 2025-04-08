test_that("event_flag_mcconnell works correctly",{
  # compare the output of event_flag_mcconnell with the output of speedfilter
  # it works for projected distances, but it will not for longlat
  expect_true(all.equal(trip::speedfilter(trip::walrus818[1:600, ], max.speed = 1000),
            event_flag_mcconnell(mt_as_move2(trip::walrus818[1:600, ]),
                           max_speed = units::as_units(1000,"m/s"))))

})
