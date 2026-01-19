# make shags dataset from csv file

shags_meta <- read.csv(system.file("extdata/shag_tidytrack_meta.csv",
                                   package = "tidytracks"))
library(dplyr)
# add geometry column (colony location point) to metadata
shags_meta <- shags_meta %>%
  sf::st_as_sf(coords = c("colony_lon", "colony_lat"), 
               crs = 4326, remove = FALSE) %>%
  # rename this geometry column to colony_coord
  dplyr::rename(colony_coord = geometry)
# get the file name
shags_csv <- system.file("extdata/shag_tidytrack_sample.csv", 
                         package = "tidytracks")
# read in the data using tt_read_data
shags_tt <- tt_read_data(events = shags_csv,
                         col_track_id = "bird_id",
                         col_coords = c("longitude", "latitude"),
                         col_date_time = c("date_gmt", "time_gmt"),
                         format_date_time = "%d/%m/%Y %H:%M:%S",
                         meta = shags_meta,
                         time_zone = "UTC",
                         crs = 4326)
usethis::use_data(shags_tt, overwrite = TRUE)
