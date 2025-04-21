test_that("event_flag_mcconnell works correctly", {
  # create a walrus dataset
  walrus_mt <- mt_as_move2(trip::walrus818[1:600, ])
  walrus_cleaned <- event_flag_mcconnell(walrus_mt,
                                        max_speed = units::as_units(1000, "m/h")
  )
  # compare the output of event_flag_mcconnell with the output of speedfilter
  # it works for projected distances, but it will not for longlat
  expect_true(all.equal(
    trip::speedfilter(trip::walrus818[1:600, ], max.speed = 1000),
    walrus_cleaned
  ))
  # check that units are handle correctly
  expect_true(all.equal(
    event_flag_mcconnell(mt_as_move2(trip::walrus818[1:600, ]),
                         max_speed = units::as_units(1, "km/h")
    ),
    walrus_cleaned))
})
