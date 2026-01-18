library(dplyr)
library(sf)
library(ggplot2)
library(rnaturalearth)
devtools::load_all()
#check package version
packageVersion("tidytracks")
#read in data
shag_data <- read.csv("inst/extdata/shag_tidytrack_sample.csv")

# metadata for colony coordinates
meta <- read.csv("inst/extdata/meta_shag_tidytrack.csv")

#check column names and remove doubles so don't end up with duplicated in metadata
?tt_hr_kde
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
image(shags_kde_1$kde[[1]]$z)

#we can see that the grid resolution is quite coarse
shags_kde_2 <- shags_mt %>%
  group_by(bird_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean")

View(shags_kde_2)

#check attributes of the kde to see which bbox and res were used
attributes(shags_kde_2)

#-7825148 -3031784 15663818  5916394 
#$res =  372840.7

?tt_hr_kde

#shags dataset too small doesnt break

#try with bba data

bba_data <- readRDS("./bba_data_cleaned.rds")

bba_mt <- tt_read_data(events = bba_data,
                       col_track_id = "track_id",
                       col_coords = c("longitude", "latitude"),
                       col_date_time = "datetime")

show_meta(bba_mt)$colony_coords <- 
  sf_point_col(show_meta(bba_mt)$lon_colony,
               show_meta(bba_mt)$lat_colony,
               crs = 4326)
show_meta(bba_mt)

## Filter and remove duplicates based on track_id and datetime  

offending_all <- bba_mt %>% 
  tt_order_time() %>%      
  group_by(track_id) %>%
  mutate(prev_time = lag(datetime),
         prev_row  = lag(row_number())) %>%
  filter(!is.na(prev_time) & datetime <= prev_time)


bba_mt <- bba_mt %>%
  filter(!(track_id == 81964 & datetime == as.POSIXct("2010-01-09 10:35:00", tz = "GMT")) &
          !(track_id == 82002 & datetime == as.POSIXct("2010-01-06 19:35:00", tz = "GMT")))

bba_mt <- bba_mt %>% tt_order_time()

### Reproject to equal area for KDEs

bba_mt <- bba_mt %>%
  sf::st_transform(crs = "+proj=laea +lat_0=-67 +lon_0=-68 +datum=WGS84 +units=m +no_defs")

#raw kde
bba_kde <- bba_mt %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = NULL, h="h_ref_mean")

image(bba_kde$kde[[1]]$z)

bba_kde_1 <- bba_mt %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean")

attributes(bba_kde_1)
?tt_hr_kde

#most polygons empty

bba_kde_2 <- bba_mt %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv")


#count number of areas of 0 in bba_kde_1
count_0_1 <- sum(units::drop_units(bba_kde_1$area) == 0, na.rm = TRUE)
count_0_2 <- sum(units::drop_units(bba_kde_2$area) == 0, na.rm = TRUE)

#marginally MORE empty polygons in the indiv h version
#given raw kde, def need to change resolution

bba_kde_3 <- bba_mt %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 10000) 
count_0_3 <- sum(units::drop_units(bba_kde_3$area) == 0, na.rm = TRUE)

#increasing the res to 10km grid cells removes all empty polygons

bba_kde_4 <- bba_mt %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv",
            res = 10000) 
count_0_4 <- sum(units::drop_units(bba_kde_4$area) == 0, na.rm = TRUE)
bba_kde_4
#just one area of 0
#find polygone with 0 area
track_81941_empty<- bba_kde_4 %>%
  filter(units::drop_units(area) == 0)

#look at that track in the original data
track_81941 <- bba_mt %>%
  filter(track_id == 81941)


#track ID 81941
#plot that track

world <- ne_countries(scale = "medium", returnclass = "sf")
wgs84 <- st_crs(4326)
ggplot() +
  geom_sf(data = world, fill = "grey", color = "black") +
  geom_sf(data = track_81941, aes(color = factor(track_id)), size = 1) +
  coord_sf(xlim = c(-39, -37), ylim = c(-54.5, -53.5))+
  theme_minimal() +
  labs(color = "Track ID")

#really tiny track!!

track_summary_stats(track_81941)
track_81941 <-  track_81941 %>% tt_order_time()
track_summary_stats(track_81941)
#131 km only, fill less than a cell

#try increasing res further
track_81941_kde <- track_81941 %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv",
            res = 10000)
track_81941_kde

#so make resolution 5km2
track_81941_kde_2 <- track_81941 %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv",
            res = 5000)
track_81941_kde_2

#find longest track
bba_mt %>%
  track_summary_stats() %>%
  arrange(desc(tot_distance)) %>%
  slice(1)

#longest track is track 82036
#look at that track in the original data
track_82036 <- bba_mt %>%
  filter(track_id == 82036)

track_82036_kde <- track_82036 %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv",
            res = 10000)

show_meta(track_82036)

#long and short track
long_and_short <- bba_mt %>%
  filter(track_id %in% c("82036", "81941"))

long_and_short_kde <- long_and_short %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_indiv",
            res = 20000)

#fills all polygons (but such a large diff that looks terrible on a map)
?tt_hr_kde


#raw kde
track_82036_kde <- track_82036 %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = NULL, h="h_ref_mean")

image(long_and_short_kde$kde[[1]]$z)
attributes(long_and_short_kde)

#plot the new kde on a map

world <- ne_countries(scale = "medium", returnclass = "sf")
wgs84 <- st_crs(4326)

#level as factor
nine_tracks_kde <- nine_tracks_kde %>% 
  mutate(level = factor(level, levels = c(0.95, 0.5)))

#reproject for map
bba_kde_map <- ggplot() +
  geom_sf(data = world, fill = "grey90", color = "grey70", linewidth =    0.3) + 
  geom_sf(
    data = nine_tracks_kde, aes(fill = level), color = "black", linewidth = 1,      alpha = 0.5
  ) +
  scale_fill_manual(
    values = c("0.95" = "lightblue", "0.5" = "orange"),
    labels = c("95% Home Range", "50% Home Range"),
    name = "KDE Level"
  ) +
  coord_sf(
    xlim = c(-40, -35), ylim = c(-55, -53), crs = wgs84, expand = TRUE
  )  +
  facet_wrap(~track_id)+
  theme_bw() +
  theme(
    legend.position = "bottom",
    strip.text = element_text(size = 14)
  )
print(bba_kde_map)

#get bounding box of nine_tracks
st_bbox(nine_tracks_kde)%>%
  print()

#project bbox to crs of nine_tracks

#get chunk of tracks
ten_tracks <- track_summary_stats(bba_mt) %>%
  arrange(tot_distance) %>%
  slice(18:25)%>%
  pull(track_id)

#add to long and short
ten_tracks <- bba_mt %>%
  filter(track_id %in% c("82036", "81941", ten_tracks))

ten_tracks_kde <- ten_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 10000)

attributes(ten_tracks_kde)


#break 1, via bbox

broken_bbox <- list(
  xmin = 2.2e6,
  ymin = 1.4e6,
  xmax = 2.4e6,
  ymax = 1.6e6
)

broken_kde_mean <- ten_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(
  levels = c(0.5, 0.95),
  h = "h_ref_mean",
  bbox = broken_bbox,
  res = 10000
)

#causes error "polygons not (all) closed, and won't even compute, because bbox is too small 

#break 2, grid resulution in relation to bandwidth
#use resulution larger than mea bandwidth

#remove the massive track to make this easier to see and define
nine_tracks <- ten_tracks %>%
  filter(!track_id %in% c("82036"))

nine_tracks_kde <- nine_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 10000) 




#add to long and short
#with mean, much more spikey but still not broken
#so changing mean bandwidth alone doesnt break the function

#tyry with a medium track so we can still view 

#Key idea: when do KDE isopleths become empty?

# Empty polygons usually occur when:
#   
#   The KDE grid does not meaningfully overlap the data
# 
# The KDE surface is too coarse to capture peaks
# 
# The bandwidth is wildly inappropriate for the data scale
# 
# The requested isopleth level cannot be achieved on the grid
# 
#induce one of these, then undo it.
#   

#if grid too fine won't work as won't join cells for along tracks?
#now this fills a polygon (probably badly)
#so make small dataset including this track, and some long tracks
#then can add in others which break at different resolutions
#not sure why breaks at h_ref_indov but nit h_ref_mean
# one linear trip for which the kernel doesn't work
# one trip that does some area-restricted search for which the kernel does work