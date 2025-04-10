# create a sample track to work on

library(move2)
set_seed(123)
mt_sim <- move2::mt_sim_brownian_motion(t = 1:20)
library(ggplot2)
ggplot() +
  geom_sf(mt_sim, aes(color = track))
