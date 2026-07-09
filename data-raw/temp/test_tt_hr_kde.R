genetta_df <- as.data.frame(matrix(
  c(
    0.5519758,
    0.27524548,
    0.5725632,
    0.12309273,
    0.5547747,
    0.06100429,
    0.6110925,
    0.16211416,
    0.5951087,
    0.09316814,
    0.5333567,
    0.11673812,
    0.5855461,
    0.11170616,
    0.5221387,
    0.11061583,
    0.5848452,
    0.17213175
  ),
  ncol = 2,
  byrow = TRUE
))
names(genetta_df) <- c("lng", "lat")

# using adehabitatHR
mask_xy_grid <- expand.grid(
  x = seq(0.40, 0.7, by = 0.01),
  y = seq(0.01, 0.4, by = 0.01)
)
sp::coordinates(mask_xy_grid) <- ~ x + y
sp::gridded(mask_xy_grid) <- TRUE

ade_genetta <- adehabitatHR::kernelUD(
  sp::SpatialPoints(genetta_df),
  h = "href",
  grid = mask_xy_grid,
  kern = "bivnorm"
)

# extract the 50% and 95% contours
ade_genetta_50 <- adehabitatHR::getverticeshr(ade_genetta, 50)
ade_genetta_95 <- adehabitatHR::getverticeshr(ade_genetta, 95)

# and now repeat it with hr_kde
# create a move2 object with just one individual
genetta_sf <- sf::st_as_sf(
  x = genetta_df,
  coords = c("lng", "lat"),
  crs = sf::st_crs(4326)
)
genetta_sf$id <- "genetta"
genetta_sf$time <- seq(
  from = as.POSIXct("2020-01-01 00:00:00"),
  by = "1 hour",
  length.out = nrow(genetta_df)
)
genetta_tt <- move2::mt_as_move2(
  genetta_sf,
  track_id_column = "id",
  time_column = "time",
)
# now group by that individual
genetta_tt <- genetta_tt %>%
  dplyr::group_by(id)
grid_list <- list(
  xmin = 0.4,
  ymin = 0.01,
  xmax = 0.7,
  ymax = 0.4,
  n = 1240
)
genetta_tt_hr <- hr_kde(
  genetta_tt,
  h = NULL,
  grid = grid_list,
  levels = c(0.5, 0.95),
  keep_objects = FALSE
)
