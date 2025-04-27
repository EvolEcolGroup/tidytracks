# From:
# https://stackoverflow.com/questions/76680983/is-there-an-sf-or-df-based-alternative-to-kernelud-to-estimate-bivariate-norma

library(adehabitatHR)
library(MASS)
library(reshape2)


genetta <- as.data.frame(matrix(
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


# using adehabitatHR
mask_xy_grid <- expand.grid(x = seq(0.01, 1, by = 0.01), y = seq(0.01, 1, by = 0.01))
coordinates(mask_xy_grid) <- ~ x + y
gridded(mask_xy_grid) <- TRUE

ade_genetta <- kernelUD(SpatialPoints(genetta),
  h = "href",
  grid = mask_xy_grid,
  kern = "bivnorm"
)

plot(ade_genetta)

# using MASS
mask.xy <- as.data.frame(expand.grid(x = seq(0.01, 1, by = 0.01), y = seq(0.01, 1, by = 0.01)))

H <- (sqrt(0.5 * (var(genetta[[1]]) + var(genetta[[2]])))) * (nrow(genetta)^-(1 / 6))

mass_genetta <- kde2d(genetta$V1,
  genetta$V2,
  n = c(100, 100),
  h = c(H * 4, H * 4),
  lims = c(range(mask.xy$x), range(mask.xy$y))
)


# using just one value for h
mass_genetta <- kde2d(genetta$V1,
  genetta$V2,
  n = c(100, 100),
  h = c(H * 4),
  lims = c(range(mask.xy$x), range(mask.xy$y))
)

##############################
# now compare them
##############################
ade_df <- adehabitatHR::as.data.frame.estUD(ade_genetta)
# rearrange this
ade_df <- dplyr::arrange(ade_df,Var2,Var1)
# get a spatial pixels data frame (can also plot it like the ade object)
mass_spdf <- SpatialPixelsDataFrame(
  points = mask.xy,
  data = data.frame(est = melt(mass_genetta$z)$value)
)
mass_df <- as.data.frame(mass_spdf)
mass_df <- dplyr::arrange(mass_df, x, y)

abs(mean(ade_df$ud - mass_df$est))<0.001 # not quite, but they are near equal


# Now fit using kernsmooth (like amt)
library(KernSmooth)
kernsm_genetta <- bkde2D(
  genetta,
  bandwidth = c(H, H),
  gridsize = c(100, 100),
  range.x = list(c(0.01, 1), c(0.01, 1))
)
kernsm_spdf <- SpatialPixelsDataFrame(
  points = mask.xy,
  data = data.frame(est = melt(kernsm_genetta$fhat)$value)
)
kernsm_df <- as.data.frame(kernsm_spdf)
kernsm_df <- dplyr::arrange(kernsm_df, x, y)

# check they are the same
abs(mean(ade_df$ud - kernsm_df$est))<0.001 # not quite, but they are near equal
abs(mean(mass_df$est - kernsm_df$est))<0.001 # not quite, but they are near equal

# visualise them
plot(ade_genetta)
plot(mass_spdf)
plot(kernsm_spdf)




## and now with ks
# BUG currently can't install the package due to a missing fortran library in R
# package mclust not installing
library(ks)


kde_genetta <- kde(genetta,
  eval.points = mask_xy, H = diag(H * 4)
)

# lazily get comparable plot
kde_genetta <- SpatialPixelsDataFrame(
  points = kde_genetta$eval.points,
  data = data.frame(est = kde_genetta$estimate)
)

plot(kde_genetta)




# to confirm this is the same h as the kernelUD output:
kde_genetta@h[["h"]]
H
kde_genetta@h[["h"]] == H

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



##

# getting contours using stars
kde_stars <- stars::st_as_stars(matrix(.x$z, nrow = nx, ncol = ny))
kde_stars <- stars::st_set_dimensions(kde_stars, "X1", .x$x)
kde_stars <- stars::st_set_dimensions(kde_stars, "X2", .x$y)
stars::st_contour(kde_stars)

# cast as stars
kde2d_to_stars <- function(.x) {
  kde_stars <- stars::st_as_stars(matrix(.x$z, nrow = nx, ncol = ny))
  kde_stars <- st_set_dimensions(kde_stars, names = c("x", "y"))
  kde_stars <- stars::st_set_dimensions(kde_stars, "x", values = .x$x)
  kde_stars <- stars::st_set_dimensions(kde_stars, "y", values = .x$y)
  foo <- stars::st_contour(kde_stars)
}

