library(dplyr)
library(sf)
library(ggplot2)
library(rnaturalearth)
library(tidytracks)

# read in rds
ten_tracks <- readRDS("data-raw/kde_example_data_bba.rds")

# Reproject to equal area for KDEs

ten_tracks<- ten_tracks %>%
  sf::st_transform(crs = "+proj=laea +lat_0=-67 +lon_0=-68 +datum=WGS84 +units=m +no_defs")

# check associated metadata
str(show_meta(ten_tracks))

# functioning (if quite coarse) kde
ten_tracks_kde <- ten_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 10000)

# Break 1: bounding box too small

broken_bbox <- list(
  xmin = 2.2e6,
  ymin = 1.4e6,
  xmax = 2.4e6,
  ymax = 1.6e6
)

ten_tracks_kde_1 <- ten_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(
    levels = c(0.5, 0.95),
    h = "h_ref_mean",
    bbox = broken_bbox,
    res = 10000
  )

# causes error "polygons not (all) closed", and won't even compute, because bbox is too small 

# Break 2: resolution too course

# remove the massive track to make this easier to see

nine_tracks <- ten_tracks %>%
  filter(!track_id %in% c("82036"))

# make kde with very coarse resolution

nine_tracks_kde_1 <- nine_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 50000) 

# count number of empty geometries
sum(sf::st_is_empty(nine_tracks_kde_1))

# try with finer res
nine_tracks_kde_2 <- nine_tracks %>%
  group_by(track_id) %>%
  tt_hr_kde(levels = c(0.5, 0.95), 
            h="h_ref_mean",
            res = 20000) 

# count number of empty geometries
sum(sf::st_is_empty(nine_tracks_kde_2))

# still one empty polygone left, on really short track
#so should maybe have warning here saying empty polygons created