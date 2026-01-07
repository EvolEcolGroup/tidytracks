library(tidytracks)
library(dplyr)

#read in data
shag_data <- read.csv("inst/extdata/shag_tidytrack_sample.csv")

# metadata for colony coordinates
meta <- read.csv("inst/extdata/meta_shag_tidytrack.csv")

#check column names and remove doubles so don't end up with duplicated in metadata

colnames(shag_data)
colnames(meta)

meta <- meta %>%
  dplyr::select(-c(sex, colony, year))

#read in as TT object

shags_mt <- tt_read_data(events = shag_data,
                       col_track_id = "bird_id",
                       col_coords = c("longitude", "latitude"),
                       col_date_time = "datetime",
                        meta= meta)

#check
head(shag_data)
head(show_meta(shags_mt))

#make sf point column for colony coordinates

show_meta(shags_mt)$colony_coords <- 
  sf_point_col(show_meta(shags_mt)$colony_lon,
               show_meta(shags_mt)$colony_lat,
               crs = 4326)
  
show_meta(shags_mt)

# Reproject to equal area for KDEs

shags_mt <- shags_mt %>%
  sf::st_transform(crs = "+proj=laea +lat_0=-67 +lon_0=-68 +datum=WGS84 +units=m +no_defs")

# Check CRS (todo- use CRSTools 'suggest projection function)
sf::st_crs(shags_mt)

#plot tracks


#create raw KDE and visualize grid
shags_kde_1 <- shags_mt %>%
  group_by(bird_id) %>%
  tt_hr_kde(levels = NULL, 
            h="h_ref_mean")

#We can plot the first kde with:
image(shags_kde$kde[[1]]$z)

#we can see that the grid resolution is quite coarse

shags_kde_2 <- shags_mt %>%
  group_by(bird_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean")

#check attributes of the kde to see which bbox and res were used
attributes(shags_kde_2)

#-7825148 -3031784 15663818  5916394 
#$res =  372840.7

?tt_hr_kde

