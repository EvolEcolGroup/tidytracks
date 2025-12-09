
create_toy_df <- function() {
  # create a simple trajectory that goes out and comes back along the longitude
  # axis
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
  coords_df$bird_id <- paste0("id_", c(rep(1, 24), rep(2, 6)))
  coords_df$bird_id <- as.factor(coords_df$bird_id)
  return(coords_df)
}


test_that("mt_trip_split works with centre_col as an sf object of same length as number of tracks", {
  
  # create the toy dataframe of longitude, latitude, date_time, bird_id
  coords_df <- create_toy_df()
  
  # convert to a tidytracks object
  test_mt <- tt_read_data(events = coords_df,
                          col_track_id = "bird_id",
                          col_coords = c("longitude", "latitude"),
                          col_date_time = "date_time"
                          )
  # quick plot to check it
  # ggplot2::ggplot(test_mt) +
  #   # ggplot2::geom_sf(ggplot2::aes(color = date_time)) +
  #   ggplot2::geom_sf(ggplot2::aes(color = bird_id)) +
  #   ggplot2::geom_sf(data = move2::mt_track_lines(test_mt))
  
  # create a centre_col of length 2 (same number as tracks in test_mt)
  centre_sf <- sf::st_as_sf(
    data.frame(
      bird_id = c("id_1", "id_2"),
      lon = rep(0, 2),
      lat = rep(0, 2)
    ),
    coords = c("lon", "lat"), crs = 4326
  )

  # now test the trip splitting

  # measure distances from point 0,0
  coords <- sf::st_coordinates(test_mt)
  centre_dist <- geodist::geodist(
    x = coords,
    y = data.frame(lon = 0, lat = 0),
    measure = "geodesic"
  ) / 1000
  # points at the colony
  at_centre <- centre_dist < 100

  # split the trips using centre_sf
  test_mt_split <- tt_split_trips(test_mt,
    centre_col = centre_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  
  # check that the trip ids are correct
  expected_trip_id_field <- c("id_1_trip_na", "id_1_trip_1",  "id_1_trip_1",  "id_1_trip_1",  
                              "id_1_trip_1",  "id_1_trip_1",  "id_1_trip_1",  "id_1_trip_1", 
                              "id_1_trip_1",  "id_1_trip_1",  "id_1_trip_1",  "id_1_trip_1",  
                              "id_1_trip_na", "id_1_trip_2",  "id_1_trip_2",  "id_1_trip_2",
                              "id_1_trip_2",  "id_1_trip_2",  "id_1_trip_na", "id_1_trip_na", 
                              "id_1_trip_3",  "id_1_trip_3",  "id_1_trip_3",  "id_1_trip_3", 
                              "id_2_trip_na", "id_2_trip_na", "id_2_trip_1",  "id_2_trip_1",  
                              "id_2_trip_1",  "id_2_trip_1")
  expect_identical(test_mt_split$trip_id, expected_trip_id_field)
  expect_equal(length(unique(test_mt_split$trip_id)), 6)
  expect_equal(length(unique(test_mt_split$bird_id)), 2)
  
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
  expect_true(
    all(
      test_mt_split$trip_id[at_centre] %in%
        c("id_1_trip_na", "id_2_trip_na")
    )
  )
  # the last trip of id_1 is incomplete
  expect_true(
    (
      show_meta(test_mt_split) %>%
        dplyr::filter(trip_id == "id_1_trip_3")
    )$trip_type == "incomplete"
  )

  # repeat with different units
  test_mt_split2 <- tt_split_trips(test_mt,
    centre_col = centre_sf,
    buffer_outbound = as_units(100000, "m"),
    buffer_inbound = as_units(100, "km"),
    complete = FALSE
  )
  expect_identical(test_mt_split, test_mt_split2)

  # change inbound buffer
  test_mt_split3 <- tt_split_trips(test_mt,
    centre_col = centre_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = FALSE
  )
  # the last trip of id_1 is incomplete
  expect_true(
    (
      show_meta(test_mt_split3) %>%
        dplyr::filter(trip_id == "id_1_trip_3")
    )$trip_type == "complete"
  )

  # check that, if we say complete = TRUE, all trips are complete
  test_mt_split4 <- tt_split_trips(test_mt,
    centre_col = centre_sf,
    buffer_outbound = as_units(100, "km"),
    buffer_inbound = as_units(300, "km"),
    complete = TRUE
  )
  # all trips should be complete
  expect_true(all((show_meta(test_mt_split4)$trip_type == "complete")))
  # there should only be 4 lines (3 trips + 1 trip)
  expect_equal(nrow(show_meta(test_mt_split4)), 4)
})

# @TODO write tests with centre inputs as different from each others, or
#   provided as additional column of meta (like in the vignette)
