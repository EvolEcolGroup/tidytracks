
# set up example dataset ----
x <- tt_read_data(events = system.file("extdata/shag_tidytrack_sample.csv", 
                                       package = "tidytracks"),
                  col_track_id = "bird_id",
                  col_coords = c("longitude", "latitude"),
                  col_date_time = c("date_gmt", "time_gmt"),
                  format_date_time = "%d/%m/%Y %H:%M:%S",
                  meta = system.file("extdata/shag_tidytrack_meta.csv",
                                     package = "tidytracks"),
                  time_zone = "UTC",
                  crs = 4326) %>%
  # filter to latitude < -5 degrees to remove error points
  dplyr::filter(sf::st_coordinates(.)[,2] < -5) %>%
  tt_order_time() %>%
  tt_clean_mcconnell(max_speed = units::as_units(80, "km/h")) %>%
  filter_by_meta(bird_id %in% c("KB_23_42778_45", "KB_23_44224_40"))

# interpolate to 10-min regular intervals
x <- move2::mt_interpolate(x, "10 mins", omit=TRUE)

# change datetimes for bird 2 to match bird 1 so they're concurrent
x$date_time[x$bird_id == "KB_23_44224_40"] <- 
  x$date_time[x$bird_id == "KB_23_42778_45"][1:length(
    x$date_time[x$bird_id == "KB_23_44224_40"]
  )]

# truncate date range so the first track isn't so long
x <- x %>%
  # dplyr::filter(date_time <= (x %>% filter(bird_id == "KB_23_44224_40") %>% pull(date_time) %>% max()))
  dplyr::filter(date_time <= as.POSIXct("2022-12-31 17:30:00", tz = "UTC"))

# read basemap (rnaturalearth ne coastline, converted to sf object)
basemap <- rnaturalearth::ne_countries(country = "antarctica", 
                                       scale = "medium",
                                       returnclass = "sf") %>%
  dplyr::select(name) # remove extra fields

# re-project both to Antarctic Polar Stereographic
x <- sf::st_transform(x, crs = 3031)
basemap <- sf::st_transform(basemap, crs = 3031)

# check datetime range
x %>%
  dplyr::group_by(bird_id) %>%
  dplyr::summarise(start = min(date_time),
                   end = max(date_time))

# TODO turn these into actual tests which test that something reasonable has been produced.
# # test tt_animate for points ----
# t_anim <- tt_animate(x = x,
#                      type = "points",
#                      basemap = basemap,
#                      wake_length = 0.5)
# 
# # test tt_animate for paths ----
# t_anim <- tt_animate(x = x,
#                      type = "paths",
#                      basemap = basemap,
#                      wake_length = 0.5)

