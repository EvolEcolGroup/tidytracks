# read in shapefile for map
library(basemaps)
library(sf)
library(terra)
library(tidyterra)
library(ggplot2)


# Get bbox of shags_tt (EPSG:4326) and turn it into an sf polygon

# having looked at KDEs expand again to - 67 and - 68 lat and- 67 and -68 lon
# set bbox to this
shags_bbox <- st_as_sfc(st_bbox(c(xmin = -68.5, xmax = -67, ymin = -68, ymax = -67), crs = st_crs(4326)))

st_crs(shags_bbox)
#  expand box by 0.5 degrees in all directions
shags_bbox_expanded <- st_buffer(shags_bbox, dist = 0.5) %>% st_set_crs(4326)


bmap <- basemap_terra(shags_bbox_expanded , map_service = "esri", map_type = "world_imagery")

map <- ggplot() +
  geom_spatraster_rgb(data = bmap) +   # basemap
  # add in coastline
  geom_event_path(data = shags_tt, aes(col = bird_id), size = 2, # tracks
                  lineend = "round")  +            # track colours
  coord_sf(crs = 4326)        # projection

map

res(bmap)
bmap_coarse <- aggregate(bmap, fact = 2, fun = "mean")
res(bmap_coarse)

# spot check the map
# check memory size of bmap

# write to file as terra

terra::writeRaster(bmap_coarse, filename = "inst/extdata/basemap_shags.tif", overwrite = TRUE)
