## code to prepare `boobies_mt` dataset goes here
set.seed(1)
# get the data from track2KBA
boobies <- track2KBA::boobies %>%
  dplyr::mutate(deployment_id = as.factor(track_id)) %>%
  dplyr::select(-c(lon_colony, lat_colony, track_id))
# sort out dates
boobies <- boobies %>%
  dplyr::mutate(date_time = lubridate::ymd_hms(paste(date_gmt, time_gmt))) %>%
  dplyr::select(-c(date_gmt, time_gmt))
boobies_sf <- sf::st_as_sf(boobies, coords = c("longitude", "latitude"),
                       crs = "+proj=longlat +datum=WGS84")
boobies_mt <- mt_as_move2(boobies_sf, track_id_column = "deployment_id",
                            time_column = "date_time")
# fill in the metadata
temp_meta <- move2::mt_track_data(boobies_mt)
temp_meta$sex <- sample(c("m","f"), nrow(temp_meta), replace = TRUE)
temp_meta$age <- sample(c(2:5), nrow(temp_meta), replace = TRUE)
center_sf <- sf::st_as_sf(data.frame(lon = rep(-5.73, nrow(temp_meta)),
                        lat = rep(-16.01, nrow(temp_meta))),
                        coords=c("lon", "lat"), crs = "+proj=longlat +datum=WGS84")
temp_meta$colony_coord <- sf::st_geometry(center_sf)
attr(boobies_mt,"track_data") <- temp_meta # also move2::mt_set_track_data()
# move2::set_track_data(boobies_mt, temp_meta) <- temp_meta
usethis::use_data(boobies_mt, overwrite = TRUE)
