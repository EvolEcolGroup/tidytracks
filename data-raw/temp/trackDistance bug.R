test_sf <- boobies_sf[1:10,]
test_sf$geometry

x1 <- sf::st_coordinates(test_sf)

trip::trackDistance(x1[-((nrow(x1) - 1):nrow(x1)), 1],
                    x1[-((nrow(x1) - 1):nrow(x1)), 2],
                    x1[-(1:2), 1], x1[-(1:2), 2],
                    longlat=TRUE)

trip::trackDistance(x1[-((nrow(x1) - 1):nrow(x1)), 1],
                    x1[-((nrow(x1) - 1):nrow(x1)), 2],
                    c(1:(nrow(x1)-4), tail(x1[,1],2)), x1[-(1:2), 2],
                    longlat=TRUE)

trip::trackDistance(x1[-nrow(x1), 1], x1[-nrow(x1), 2],
                    x1[-1, 1], x1[-1, 2],
                    longlat=TRUE)

# project to local equal area
library(sf)
test_crs <- move2::mt_aeqd_crs(test_sf$geometry[1])
test_sf_proj <- sf::st_transform(test_sf, test_crs)
x1 <- sf::st_coordinates(test_sf_proj)



trip::trackDistance(x1[-((nrow(x1) - 1):nrow(x1)), 1],
                    x1[-((nrow(x1) - 1):nrow(x1)), 2],
                    x1[-(1:2), 1], x1[-(1:2), 2],
                    longlat=FALSE)

################################

x1 <- 1:10
x2 <- 2:11
y1 <- 1:10
y2 <- 2:11
trip::trackDistance(x1,y1, x2, y2, longlat=TRUE)

# now make some NAs (which should break the distances)
x2[1:9] <- NA
trip::trackDistance(x1,y1, x2, y2, longlat=TRUE)

# and yet we get identical results with NAs...


