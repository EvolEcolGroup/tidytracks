xg <- c(0, 1, 2, 3, 4, 5)
yg <- c(0, 1, 2, 3, 4, 5)
xy <- matrix(c(0, 0, 1, 1, 2, 2, 3, 3, 4, 4), ncol=2)
htmp <- 0.5



adehabitatHR:::kernelhr(double(length(xg)*length(yg)),as.double(xg),
                        as.double(yg),
                        as.integer(length(yg)), as.integer(length(xg)),
                        as.integer(nrow(xy)), as.double(htmp),
                        as.double(xy[,1]), as.double(xy[,2]))


toto<-.C(adehabitatHR:::kernelhr, double(length(xg)*length(yg)),as.double(xg),
         as.double(yg),
         as.integer(length(yg)), as.integer(length(xg)),
         as.integer(nrow(xy)), as.double(htmp),
         as.double(xy[,1]), as.double(xy[,2]),
         PACKAGE="adehabitatHR")

toto<-.C(adehabitatHR:::kernelhr, double(length(xg)*length(yg)),as.double(xg),
         as.double(yg),
         as.integer(length(yg)), as.integer(length(xg)),
         as.integer(nrow(xy)), as.double(htmp),
         as.double(xy[,1]), as.double(xy[,2]))
