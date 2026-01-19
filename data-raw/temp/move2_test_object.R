# create a sample track to work on

library(move2)
set.seed(123)
date_time_seq <- as.POSIXct(seq(
  from = lubridate::mdy_hm("01-01-2021 00:00"),
  length.out = 20, ,
  by = "12 hours"
))

mt_sim <- move2::mt_sim_brownian_motion(t = date_time_seq, sigma = 0.001)
sf::st_crs(mt_sim) <- 4326
mt_sim$track <- as.factor(mt_sim$track)
library(ggplot2)
ggplot(mt_sim) +
  geom_sf(aes(color = track))
mt_speed(mt_sim)
saveRDS(mt_sim, "./tests/testthat/testdata/mt_sim1.rds")
