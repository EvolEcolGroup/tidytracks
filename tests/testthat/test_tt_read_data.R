test_that("tt_read_data throws error if NAs in events table", {
  example_df <- data.frame(
    track_id = c(1, 1, 2, 2),
    lon = c(10, NA, 20, 21),
    lat = c(50, 51, NA, 52),
    date_time = c("2024-01-01 12:00:00", "2024-01-01 12:10:00",
                 "2024-01-02 13:00:00", "2024-01-02 13:10:00")
  )
  expect_error(
    tt_read_data(
      events = example_df,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    regexp = "Column lon contains missing values (NAs). Please remove or impute these before proceeding.", fixed=TRUE
  )
})

# test with events CSV and meta CSV
test_that("tt_read_data works with events CSV and meta CSV", {

  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    meta = test_path("testdata/test_tt_read_data_meta.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 4)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id", "age", "sex", "location") %in%
        names(show_meta(example_tt))))
})

# test with events CSV only, simple version
#   (shouldn't make any extra metadata)
test_that("tt_read_data works with events CSV and no meta", {
  
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 1)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id") %in%
        names(show_meta(example_tt))))
})

# test with events CSV only, verbose version
#   (should move extra columns to metadata)
test_that("tt_read_data works with verbose events CSV and no meta", {
  
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_verbose.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 4)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id", "age", "sex", "location") %in%
        names(show_meta(example_tt))))
})

# test with events dataframe only, simple version
#   (shouldn't make any extra metadata)
test_that("tt_read_data works with events dataframe", {
  
  df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  
  example_tt <- tt_read_data(
    events = df,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 1)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id") %in%
        names(show_meta(example_tt))))
  
})


# test with events dataframe and meta dataframe
test_that("tt_read_data works with dataframes for both events and meta", {
  
  df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_meta <- read.csv(test_path("testdata/test_tt_read_data_meta.csv"))
  
  example_tt <- tt_read_data(
    events = df,
    meta = df_meta,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 4)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id", "age", "sex", "location") %in%
        names(show_meta(example_tt))))
  
})


# test with events dataframe only, verbose version
#   (should move extra columns to metadata)
test_that("tt_read_data works with verbose events dataframe and no meta", {
  
  df <- read.csv(test_path("testdata/test_tt_read_data_verbose.csv"))
  
  example_tt <- tt_read_data(
    events = df,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  expect_true(length(names(show_meta(example_tt))) == 4)
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("track_id", "age", "sex", "location") %in%
        names(show_meta(example_tt))))
  
})

# test with events CSV with separate date and time fields
test_that("tt_read_data works with events CSV with separate date and time fields", {
  
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_separate_date_time.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = c("date","time")
  )
  
  # NB. when tt_read_data is given separate date and time columns, it combines
  # them into a single date_time column in the resulting object.
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  
  # check that the date and time in the first row are correct
  expect_equal(
    example_tt$date_time[1],
    as.POSIXct("2024-01-01 12:00:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  
})

# test errors if you try to parse a dataframe that doesn't have the correct
# fields
test_that("tt_read_data gives errors for missing or incorrect fields", {
  
  # no track_id field
  df_no_id <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_no_id$track_id <- NULL
  expect_error(
    tt_read_data(
      events = df_no_id,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    "Column track_id not found in the events data."
  )
  
  # no date_time field
  df_no_date_time <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_no_date_time$date_time <- NULL
  expect_error(
    tt_read_data(
      events = df_no_date_time,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    "Column date_time not found in the events data."
  )
  
  # no coord field
  df_no_coords <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_no_coords$lon <- NULL
  expect_error(
    tt_read_data(
      events = df_no_coords,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    "Columns lon, lat not found in the events data."
  )
  
  # no track_id field in meta
  df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_meta_no_id <- read.csv(test_path("testdata/test_tt_read_data_meta.csv"))
  df_meta_no_id$track_id <- NULL
  
  expect_error(
    tt_read_data(
      events = df,
      meta = df_meta_no_id,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    "Column track_id not found in the meta data."
  )
  
  # date_time not given as a character of length 1 or 2
  df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  expect_error(
    tt_read_data(
      events = df,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = c("date_time", "extra", "field")
    ),
    "col_date_time must be a character vector of length 1 or 2."
  )
  
})


# test with un-parse-able date_time field(s)

test_that("tt_read_data gives error for un-parse-able date_time field(s)", {
  
  # with date_time that's just another character string
  df_bad_date_time <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_bad_date_time$date_time <- "not a date"
  expect_error(
    tt_read_data(
      events = df_bad_date_time,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    regexp = "Failed to parse date-time field(s) 'date_time'", fixed=TRUE
  )
  
  # with multiple different date_time formats in the same field
  df_bad_date_time <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_bad_date_time$date_time[2] <- "01/01/2024 12:10"  # different format
  expect_error(
    tt_read_data(
      events = df_bad_date_time,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    regexp = "Failed to parse date-time field(s) 'date_time'", fixed=TRUE
  )
    
  
  # test for separate date and time fields where one is bad
  df_diff_date_time <- read.csv(test_path("testdata/test_tt_read_data_separate_date_time.csv"))
  df_diff_date_time$date[2] <- "not a date"  # not parse-able
  expect_error(
    tt_read_data(
      events = df_diff_date_time,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = c("date","time")
    ),
    regexp = "Failed to parse date-time field(s) 'date', 'time'", fixed=TRUE
  )
  
})


# test with different but parse-able date_time field(s)
test_that("tt_read_data works with a variety of date_time field(s) formats", {
  
  # test with date_time formats starting with dd instead of yyyy
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_diff_date_times.csv"),
    col_track_id = "trackid",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time_posix"
  )
  expect_s3_class(example_tt, "move2")
  expect_equal( # check first date_time parsed correctly
    example_tt$date_time_posix[1],
    as.POSIXct("2008-02-12 14:30:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  expect_equal(colnames(example_tt), c("trackid", "date_time_posix", "geometry"))
  
  # check it works on separate date and time fields with different formats
  df_diff_date_time <- read.csv(test_path("testdata/test_tt_read_data_separate_date_time.csv"))
  df_diff_date_time$date <- "01/01/2024"  # different date format
  example_tt <- tt_read_data(
    events = df_diff_date_time,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = c("date","time")
  )
  expect_s3_class(example_tt, "move2")
  expect_equal(
    example_tt$date_time[2],
    as.POSIXct("2024-01-01 12:10:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
})


# test with specifying the format_date_time parameter
test_that("tt_read_data works with format_date_time parameter", {
  
  # test with date_time formats starting with dd instead of yyyy
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_diff_date_times.csv"),
    col_track_id = "trackid",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time_posix",
    format_date_time = "%d/%m/%Y %H:%M"
  )
  expect_s3_class(example_tt, "move2")
  expect_equal( # check first date_time parsed correctly
    example_tt$date_time_posix[1],
    as.POSIXct("2008-02-12 14:30:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  expect_equal(colnames(example_tt), c("trackid", "date_time_posix", "geometry"))
  
  # as above, but without specifying format_date_time - does it choose the correct format?
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_diff_date_times.csv"),
    col_track_id = "trackid",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time_posix"
  )
  expect_s3_class(example_tt, "move2")
  expect_equal( # check first date_time parsed correctly
    example_tt$date_time_posix[1],
    as.POSIXct("2008-02-12 14:30:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  expect_equal(colnames(example_tt), c("trackid", "date_time_posix", "geometry"))
  
  # test with the wrong format_date_time parameter
  expect_error(
    tt_read_data(
      events = test_path("testdata/test_tt_read_data_diff_date_times.csv"),
      col_track_id = "trackid",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time_posix",
      format_date_time = "%d-%m-%Y %H:%M" # a subtle but important formatting difference!
    ),
    regexp = "Some date-time values could not be parsed using the provided format_date_time", fixed=TRUE)
})

# test with multiple date_time fields, make sure the correct one is chosen
test_that("tt_read_data works with multiple date_time_xyz fields", {
  
  test_df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  test_df$date_time_posix <- "not the real date_time field"
  test_df$date_time_old <- "also not the real date_time field"
  
  example_tt <- tt_read_data(
    events = test_df,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "date_time"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  
  # check that the date and time in the first row are correct
  expect_equal(
    example_tt$date_time[1],
    as.POSIXct("2024-01-01 12:00:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  
  # test again, this time there is no date_time field but multiple date_time_xyz field
  test_df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  test_df$date_time_real <- test_df$date_time
  test_df$date_time <- NULL
  test_df$date_time_abc <- "not the real date_time field"
  test_df$date_time_old <- "also not the real date_time field"
  
  expect_error(
    tt_read_data(
      events = test_df,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time"
    ),
    regexp = "Column date_time not found in the events data.", fixed=TRUE
  )
  
})

# test error when some date_times have a different format
test_that("tt_read_data gives error when the provided date_time format is wrong", {
  
  expect_error(
    tt_read_data(
      events = read.csv(test_path("testdata/test_tt_read_data_simple.csv")),
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "date_time",
      format_date_time = "%d/%m/%Y %H:%M:%S"
    ),
    regexp = "Some date-time values could not be parsed using the provided format_date_time", fixed=TRUE
  )
  
})


