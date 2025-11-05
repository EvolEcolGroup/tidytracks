# make small example test data files for tt_read_data
# and save small CSV files into tests/testthat/testdata

# use the move2 function to simulate data
set.seed(42)
data <- mt_sim_brownian_motion(tracks = letters[1:4])
head(data)
nrow(data)

# need to change time to a datetime, and make up some metadata for each track

# extract the simulated data as a dataframe (not a move2 object) so we can 
#   play around with it without upsetting the move2 data structures

# make a vector of 10 datetimes as a sequence at 10-min intervals
ten_dttms <- seq(
  from = as.POSIXct("2024-01-01 12:00:00", tz = "UTC"),
  by = "10 min",
  length.out = 10
)

df <- data.frame(
  track_id = as.character(data$track),
  datetime = rep(ten_dttms, times = 4),
  lon = sf::st_coordinates(data)[, 1],
  lat = sf::st_coordinates(data)[, 2]
)
head(df)
nrow(df)

# now invent some metadata for each track_id
meta <- data.frame(
  track_id = letters[1:4],
  age = c(2, 2, 4, 1),
  sex = c("f", "m", "f", "m"),
  location = c(rep("island", 3), "mainland")
)

# make a version of df that has meta in it
df_with_meta <- merge(df, meta, by = "track_id")

# save these as CSVs in tests/testthat/testdata
write.csv(
  df,
  file = "tests/testthat/testdata/test_tt_read_data_simple.csv",
  row.names = FALSE
)
write.csv(
  df_with_meta,
  file = "tests/testthat/testdata/test_tt_read_data_verbose.csv",
  row.names = FALSE
)
write.csv(
  meta,
  file = "tests/testthat/testdata/test_tt_read_data_meta.csv",
  row.names = FALSE
)

# make a version with separate date and time fields
# TODO


