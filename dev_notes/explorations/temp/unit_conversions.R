x <- boobies_sf
x <- sf::st_transform(x, 3857)
x <- sf::st_transform(
  x,
  "+proj=aeqd +lat_0=90 +lon_0=0 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=km +no_defs"
)


# set the units for the distance
if (sf::st_is_longlat(x)) {
  is_longlat <- TRUE
  dist_units <- as_units("m/s")
} else {
  is_longlat <- FALSE
  dist_units <- sf::st_crs(x)$ud_unit / as_units("s")
}
# now we take a parameter that we have been given and transform it in the units
# of the distances
foo <- as_units(50, "km/h")
set_units(foo, dist_units, mode = "standard")
