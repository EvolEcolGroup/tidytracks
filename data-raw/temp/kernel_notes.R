# From:
# https://stackoverflow.com/questions/76680983/is-there-an-sf-or-df-based-alternative-to-kernelud-to-estimate-bivariate-norma

library(adehabitatHR)
library(MASS)
library(reshape2)

# using adehabitatHR
G_genetta <- as.data.frame(matrix(
  c(
    0.5519758, 0.27524548,
    0.5725632, 0.12309273,
    0.5547747, 0.06100429,
    0.6110925, 0.16211416,
    0.5951087, 0.09316814,
    0.5333567, 0.11673812,
    0.5855461, 0.11170616,
    0.5221387, 0.11061583,
    0.5848452, 0.17213175
  ),
  ncol = 2, byrow = TRUE
))

mask_xy_grid <- expand.grid(x = seq(0.01, 1, by = 0.01), y = seq(0.01, 1, by = 0.01))
coordinates(mask_xy_grid) <- ~ x + y
gridded(mask_xy_grid) <- TRUE

ade_G_genetta <- kernelUD(SpatialPoints(G_genetta),
  h = "href",
  grid = mask_xy_grid,
  kern = "bivnorm"
)

plot(ade_G_genetta)

# using MASS
mask.xy <- as.data.frame(expand.grid(x = seq(0.01, 1, by = 0.01), y = seq(0.01, 1, by = 0.01)))

H <- (sqrt(0.5 * (var(G_genetta[[1]]) + var(G_genetta[[2]])))) * (nrow(G_genetta)^-(1 / 6))

MASS_G_genetta <- kde2d(G_genetta$V1,
  G_genetta$V2,
  n = c(100, 100),
  h = c(H * 4, H * 4),
  lims = c(range(mask.xy$x), range(mask.xy$y))
)

# lazily get comparable plots
MASS_G_genetta <- SpatialPixelsDataFrame(
  points = mask.xy,
  data = data.frame(est = melt(MASS_G_genetta$z)$value)
)

plot(MASS_G_genetta)


## and now with ks
# BUG currently can't install the package due to a missing fortran library in R
# package mclust not installing
library(ks)


kde_G_genetta <- kde(G_genetta,
  eval.points = mask_xy, H = diag(H * 4)
)

# lazily get comparable plot
kde_G_genetta <- SpatialPixelsDataFrame(
  points = kde_G_genetta$eval.points,
  data = data.frame(est = kde_G_genetta$estimate)
)

plot(kde_G_genetta)




# to confirm this is the same h as the kernelUD output:
kde_G_genetta@h[["h"]]
H
kde_G_genetta@h[["h"]] == H

########################################################
# and another dataset
A_buselaphus <- as.data.frame(matrix(
  c(
    0.5109837, 0.1247711,
    0.5109837, 0.1247711,
    0.5893287, 0.1613403,
    0.5893287, 0.1613403,
    0.5893287, 0.1613403
  ),
  ncol = 2, byrow = TRUE
))

# using kernelUD
ade_A_buselaphus <- kernelUD(SpatialPoints(A_buselaphus),
  h = "href",
  grid = mask_xy_grid,
  kern = "bivnorm"
)

plot(ade_A_buselaphus)

# using kde
# kde_A_buselaphus <- kde(A_buselaphus,
#                        eval.points = mask_xy)
H_bus <- (sqrt(0.5 * (var(A_buselaphus[[1]]) + var(A_buselaphus[[2]])))) * (nrow(A_buselaphus)^-(1 / 6))


MASS_A_buselaphus <- kde2d(A_buselaphus$V1,
  A_buselaphus$V2,
  n = c(100, 100),
  h = c(H_bus * 4, H_bus * 4),
  lims = c(range(mask.xy$x), range(mask.xy$y))
)




# lazily get comparable plot
MASS_A_buselaphus <- SpatialPixelsDataFrame(
  points = mask.xy,
  data = data.frame(est = melt(MASS_A_buselaphus$z)$value)
)


plot(MASS_A_buselaphus)

# a simple kde wrapper to use sf:
# https://github.com/r-spatial/sf/issues/1201
