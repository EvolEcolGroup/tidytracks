library("adehabitatHR")
data(puechabonsp)
# Create a move2 object with the relocations
boar_sf <- sf::st_as_sf(puechabonsp$relocs)

wildboar_mt <- move2::mt_as_move2(sf::st_as_sf(puechabonsp$relocs))
