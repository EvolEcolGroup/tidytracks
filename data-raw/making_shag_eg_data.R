# doctor shags data
library(tidytracks)
library(sf)
library(dplyr)

# first read in


data("shags_tt", package = "tidytracks")

# inspect colnames
shags_tt %>% colnames()

# can't rename straight away as breaks move2 obj, make into df and drop geom then read back in

show_meta(shags_tt)

# because is move2 with metadata, can't rename ID col,
# will try making metadata events data and then creating a df.
#then save the df,read back in as tt object, and save as shags rds
# lastly remove the bird that violates the latitude filter

# move all metadata cols to event attribute usingas_event_column

# show meta colnammes
event_cols <- colnames(show_meta(shags_tt))

shags_tt_events <- shags_tt %>%
  as_event_column(all_of(event_cols)) 

show_meta(shags_tt_events)


# now make into df and drop geom, split geometry into lat and lon
coords <- st_coordinates(shags_tt_events)

shags_df <- shags_tt_events %>%
  sf::st_drop_geometry() %>%
  as.data.frame() %>%     # remove move2 attributes
  mutate(
    longitude = coords[,1],
    latitude = coords[,2]
  ) 

head(shags_df)


# rename bird id to track_id
shags_df <- shags_df %>%
  rename(track_id = bird_id)

# read back in as tt object

?tt_read_data

shags <- tt_read_data(
  events = shags_df,
  col_track_id = "track_id",
  col_coords = c("longitude", "latitude"),
  col_date_time = "date_time",
  crs = 4326,
  time_zone = "UTC")

show_meta(shags)

## need to do a proper lat filter because think more than 1 violate it 

# now filter for all except one bird that violates the latitude filter (KB_23_44224_40)
unique(shags$track_id)
shags <- shags %>%
  filter(track_id != "KB_23_42962_38")

# save new rda as shags_new - as RDA file
save(shags, file = "data/shags_new.rda")

