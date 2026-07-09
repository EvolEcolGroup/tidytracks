library("adehabitatHR")
data(puechabonsp)
# guess the crs as there is no crs for this object
boar_sf <- sf::st_as_sf(puechabonsp$relocs)

# There is no CRS defined in the object some trial and error suggests that the
# correct CRS is 27573 (Lambert 93 / France III)
sf::st_crs(boar_sf) <- 27573

# # To verify it, we first convert the coordinates to WGS84 and then check the
# # coordinates
# boar_wgs84 <- st_transform(boar_sf, 4326)
# # Verify coordinates: They should be ~ Latitude 43.7, Longitude 3.6
# print(head(st_coordinates(boar_wgs84)))
# # finally plot this to verify the locations look correct
# # to point line up nicely wiht natural features
# library(leaflet)
# leaflet(boar_wgs84) %>%
#   addProviderTiles(providers$Esri.WorldImagery) %>%
#   addCircleMarkers(radius = 3, color = "yellow")

boar_sf$Date <- as.POSIXct(
  (boar_sf$Date - max(boar_sf$Date)) * 8640,
  tz = "UTC"
)
names(boar_sf) <- tolower(names(boar_sf))
# Create a move2 object with the relocations

wildboar_tt <- move2::mt_as_move2(
  boar_sf,
  track_id_column = "name",
  time_column = "date"
)
# save it as an RDS object in the testthat  directory
saveRDS(wildboar_tt, file = "./tests/testthat/testdata/wildboar_tt.rds")
saveRDS(boar_sf, file = "./vignettes/articles/articles_data/wildboar_tt.rds")
