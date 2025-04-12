test_that("mt_trip_split works as expected", {
  # create a simple trajectory that goes out and comes back along the longitude
  # axis
  library(dplyr)
  set.seed(1)
  coords_df <- data.frame(
    longitude = c(
      0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0.5, -2, -3,
      -4, -5, -3 - 1.2, -0.3, -0.1, 1, 3, 4, 2.1,
      0.3, 0.7, 2.1, 4, 3, 1.3
    ), # second individual
    latitude = rnorm(30, mean = 0, sd = 0.1) +
      c(
        rep(0, 6), rep(0.3, 5), rep(0.15, 7), rep(-0.3, 6),
        rep(0.1, 6)
      )
  )
  coords_df$date_time <- c(
    seq(
      from = as.POSIXct("2020-01-01 00:00:00"),
      by = "1 hour", length.out = 24
    ),
    seq(
      from = as.POSIXct("2020-02-10 00:00:00"),
      by = "1 hour", length.out = 6
    )
  )
  coords_df$deployment_id <- paste0("id_", c(rep(1, 24), rep(2, 6)))
  coords_df$deployment_id <- as.factor(coords_df$deployment_id)
  coords_df$lon_colony <- 0
  coords_df$lat_colony <- 0
  coords_df <- sf::st_as_sf(coords_df,
    coords = c("longitude", "latitude"),
    crs = "+proj=longlat +datum=WGS84"
  ) # todo use equal area proj in km
  test_mt <- move2::mt_as_move2(coords_df,
    track_id_column = "deployment_id",
    time_column = "date_time"
  )
  # ggplot(test_mt) + geom_sf(aes (color = date_time))+
  #  geom_sf(data = move2::mt_track_lines(test_mt))
  # add some metadata
  center_sf <- sf::st_as_sf(
    data.frame(
      lon = rep(0, 1),
      lat = rep(0, 1)
    ),
    coords = c("lon", "lat"), crs = "+proj=longlat +datum=WGS84"
  )

  # now test the trip splitting

  # measure distances from point 0,0
  coords <- sf::st_coordinates(test_mt)
  center_dist <- geodist::geodist(
    x = coords,
    y = data.frame(lon = 0, lat = 0),
    measure = "geodesic"
  ) / 1000
  # points at the colony
  at_center <- center_dist < 100

  # test the trip splitting
  test_mt_split <- mt_split_trips(test_mt,
    center_col = center_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  # check that the trip ids are correct
  expect_equal(length(unique(test_mt_split$trip_id)), 6)
  expect_equal(length(unique(test_mt_split$deployment_id)), 2)
  # the first trip is from 2 to 12
  expect_true(
    all(
      range(
        which(
          test_mt_split$trip_id == "id_1_trip_1"
        )
      ) == c(2, 12)
    )
  )
  # detect correctly time at colony
  expect_true(all(test_mt_split$trip_id[at_center] %in%
    c("id_1_trip_na", "id_2_trip_na")))
  # the last trip of id_1 is incomplete
  expect_true((mt_show_meta(test_mt_split) %>%
    filter(trip_id == "id_1_trip_3"))$trip_type == "incomplete")

  # repeat with a differnet units
  test_mt_split2 <- mt_split_trips(test_mt,
    center_col = center_sf,
    buffer_outbound = as_units(100000, "m"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  expect_identical(test_mt_split, test_mt_split2)

  # change inbound buffer
  test_mt_split3 <- mt_split_trips(test_mt,
    center_col = center_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = FALSE
  )
  # the last trip of id_1 is incomplete
  expect_true((mt_show_meta(test_mt_split3) %>%
    filter(trip_id == "id_1_trip_3"))$trip_type == "complete")

  # check that, if we say complete = TRUE, all trips are complete
  test_mt_split4 <- mt_split_trips(test_mt,
    center_col = center_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = TRUE
  )
  # all trips should be complete
  expect_true(all((mt_show_meta(test_mt_split4)$trip_type == "complete")))
  # there should only be 4 lines (3 trips + 1 trip)
  expect_equal(nrow(mt_show_meta(test_mt_split4)), 4)

})

# @TODO write tests with center inputs as different from each others, or
#   provided as additional column of meta (like in the vignette)
