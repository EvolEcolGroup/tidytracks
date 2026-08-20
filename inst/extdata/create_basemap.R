# read in shapefile for map
library(basemaps)
library(sf)
library(terra)
library(tidyterra)
library(ggplot2)


# Get bbox of shags_tt (EPSG:4326) and turn it into an sf polygon
shags_bbox <- st_as_sfc(st_bbox(shags_tt)) # is wgd84
st_crs(shags_bbox)
#  expand box by 0.5 degrees in all directions
shags_bbox_expanded <- st_buffer(shags_bbox, dist = 0.5) %>% st_set_crs(4326)

bmap <- basemap_terra(shags_bbox_expanded , map_service = "esri", map_type = "world_imagery")

map <- ggplot() +
  geom_spatraster_rgb(data = bmap_coarse) +   # basemap
  # add in coastline
  geom_event_path(data = shags_tt, aes(col = bird_id), size = 2, # tracks
                  lineend = "round")  +            # track colours
  coord_sf(crs = 4326)        # projection

res(bmap)
bmap_coarse <- aggregate(bmap, fact = 2, fun = "mean")
res(bmap_coarse)

# spot check the map
# check memory size of bmap
basemap_shags <- bmap
saveRDS(
  basemap_shags,
  file = "inst/extdata/basemap_shags.rds")

