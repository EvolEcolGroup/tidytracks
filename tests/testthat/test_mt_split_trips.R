# create a simple trajectory that goes out and comes back along the longitude axis
set.seed(1)
coords <- data.frame (longitude=c(0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 1, -2, -3,
                                  -4, -5, -6, -4, -3, -1.9, 3, 4, 3.1),
                      latitude=rnorm(24, mean=0, sd=0.1) +
                        c(rep(0,6), rep(0.3, 5), rep(0.15,6), rep(-0.3, 6)))
coords$date_time <- seq(from=as.POSIXct("2020-01-01 00:00:00"),
                          by="1 hour", length.out=nrow(coords))
coords$track_id <- rep(1, nrow(coords))
coords$track_id <- as.factor(coords$track_id)
coords$deployment_id <- coords$track_id
coords$lon_colony <- 0
coords$lat_colony <- 0
coords <- sf::st_as_sf(coords, coords = c("longitude", "latitude"),
                            crs = "+proj=longlat +datum=WGS84")
test_mt <- move2::mt_as_move2(coords, track_id_column = "track_id",
                            time_column = "date_time")
ggplot(test_mt) + geom_sf(aes (color = date_time))+
  geom_sf(data = move2::mt_track_lines(test_mt))
