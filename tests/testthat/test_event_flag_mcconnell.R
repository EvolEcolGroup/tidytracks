walrus_sub <- trip::walrus818[1:600, ]
# create a walrus dataset
walrus_mt <- mt_as_move2(walrus_sub)

test_that("event_flag_mcconnell works correctly", {
  walrus_cleaned <-
    event_flag_mcconnell(walrus_mt,
                         max_speed = as_units(1000, "m/h"))
  # compare the output of event_flag_mcconnell with the output of speedfilter
  # it works for projected distances, but it will not for longlat
  expect_true(all.equal(
    trip::speedfilter(walrus_sub, max.speed = 1000),
    walrus_cleaned
  ))
  # check that units are handle correctly
  expect_true(all.equal(
    event_flag_mcconnell(mt_as_move2(trip::walrus818[1:600, ]),
                         max_speed = as_units(1, "km/h")
    ),
    walrus_cleaned))
})

test_that("tt_clean_mcconnel correctly handles filtered data",{
  # first check that setting to null works
  walrus_clean_null <- tt_clean_mcconnell(walrus_mt,
                                          max_speed = as_units(1000, "m/h"),
                                          flag_action = "null")
  walrus_clean_rm <- tt_clean_mcconnell(walrus_mt,
                                        max_speed = as_units(1000, "m/h"),
                                        flag_action = "remove")
  # number of rows in rm is equal to all rows minus the null
  nrow(walrus_clean_null)- sum(is.na(sf::st_coordinates(walrus_clean_null))[,1])
})
