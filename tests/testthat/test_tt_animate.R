
# only rnu this test if gganimate package is installed
skip_if_not_installed("gganimate")
skip_if_not_installed("rnaturalearth")

# set up example dataset ----
# TODO save a cleaned mini example .rds file somewhere to use for tests like this
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
  # filter by latitude to remove obvious errors
  dplyr::filter(sf::st_coordinates(.)[,2] < -5) %>%
  # just two birds
  filter_by_meta(bird_id %in% c("KB_23_42778_45", "KB_23_44224_40")) %>%
  # clean the data
  tt_order_time() %>%
  tt_clean_mcconnell(max_speed = units::as_units(80, "km/h")) %>%
  # interpolate to 10-min regular intervals
  move2::mt_interpolate(., "10 mins", omit=TRUE)

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
# x %>%
#   dplyr::group_by(bird_id) %>%
#   dplyr::summarise(start = min(date_time),
#                    end = max(date_time))


# test tt_animate for points ----
test_that("tt_animate produces a gganim object with type=points", {
  list_anim <- tt_animate(x = x,
                          type = "points",
                          basemap = basemap,
                          wake_length = 0.5,
                          label_format = "%b %e %H:%M")
  # list_anim should be a list of length 2 with names p_anim and n_frames
  expect_type(list_anim, "list")
  expect_named(list_anim, c("p_anim", "n_frames"))
  # the second element should be a single integer (n frames)
  expect_type(list_anim$n_frames, "integer")
  # the first element should be a gganim object
  expect_s3_class(list_anim$p_anim, "gganim")
})

# test tt_animate for paths ----
test_that("tt_animed produces a gganim object with type=path", {
  list_anim <- tt_animate(x = x,
                          type = "paths",
                          basemap = basemap,
                          wake_length = 0.5,
                          label_format = "%b %e %H:%M")
  # list_anim should be a list of length 2 with names p_anim and n_frames
  expect_type(list_anim, "list")
  expect_named(list_anim, c("p_anim", "n_frames"))
  # the second element should be a single integer (n frames)
  expect_type(list_anim$n_frames, "integer")
  # the first element should be a gganim object
  expect_s3_class(list_anim$p_anim, "gganim")
})
  
# for manual testing only: animate the gganim using av_renderer()
# gganimate::animate(plot = list_anim$p_anim,
#                    nframes = list_anim$n_frames,
#                    fps = 10,
#                    renderer = gganimate::av_renderer())

