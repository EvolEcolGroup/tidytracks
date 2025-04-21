library("adehabitatHR")
data(puechabonsp)
# guess the crs as there is no crs for this object
boar_sf <- sf::st_as_sf(puechabonsp$relocs, crs = 2154)

boar_sf$Date <- as.POSIXct((boar_sf$Date - max(boar_sf$Date)) * 8640, tz = "UTC")

# Create a move2 object with the relocations

wildboar_mt <- move2::mt_as_move2(boar_sf,
  track_id_column = "Name",
  time_column = "Date"
)
# save it as an RDS object in the testthat  directory
saveRDS(wildboar_mt, file = "./tests/testthat/testdata/wildboar_mt.rds")
