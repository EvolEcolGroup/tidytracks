# test with events CSV and meta CSV
test_that("tt_read_data works with events CSV and meta CSV", {

  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_simple.csv"),
    meta = test_path("testdata/test_tt_read_data_meta.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    col_date_time = "datetime"
  )
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "datetime", "geometry") %in% names(example_tt)))
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
    events = test_path("testdata/test_tt_read_data_separate_datetime.csv"),
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = c("date","time")
  )
  
  # NB. when tt_read_data creates a datetime field from a date and time field
  # it calls it date_time (different from datetime that we normally use).
  
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
      col_date_time = "datetime"
    ),
    "Column track_id not found in the events data."
  )
  
  # no datetime field
  df_no_datetime <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_no_datetime$datetime <- NULL
  expect_error(
    tt_read_data(
      events = df_no_datetime,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "datetime"
    ),
    "Column datetime not found in the events data."
  )
  
  # no coord field
  df_no_coords <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_no_coords$lon <- NULL
  expect_error(
    tt_read_data(
      events = df_no_coords,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "datetime"
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
      col_date_time = "datetime"
    ),
    "Column track_id not found in the meta data."
  )
  
  # datetime not given as a character of length 1 or 2
  df <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  expect_error(
    tt_read_data(
      events = df,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = c("datetime", "extra", "field")
    ),
    "col_date_time must be a character vector of length 1 or 2."
  )
  
})


# test with un-parse-able datetime field(s)

test_that("tt_read_data gives error for un-parse-able datetime field(s)", {
  
  # with datetime that's just another character string
  df_bad_datetime <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_bad_datetime$datetime <- "not a date"
  expect_error(
    tt_read_data(
      events = df_bad_datetime,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = "datetime"
    ),
    "Failed to parse date-time field(s) 'datetime'. Please check that the format is consistent and uses a standard format (e.g. YYYY-mm-dd hh:mm:ss).",
    fixed = TRUE
  )
  
  # TODO add tests for separate date and time fields where one is bad
  df_diff_datetime <- read.csv(test_path("testdata/test_tt_read_data_separate_datetime.csv"))
  df_diff_datetime$date[2] <- "not a date"  # not parse-able
  expect_error(
    tt_read_data(
      events = df_diff_datetime,
      col_track_id = "track_id",
      col_coords = c("lon", "lat"),
      col_date_time = c("date","time")
    ),
    "Failed to parse date-time field(s) 'date', 'time'. Please check that the format is consistent and uses a standard format (e.g. YYYY-mm-dd hh:mm:ss).",
    fixed = TRUE
  )
  
})


# test with different but parse-able datetime field(s)
test_that("tt_read_data works with a variety of datetime field(s) formats", {
  
  # with multiple different datetime formats in the same field - UPDATE this now works
  df_bad_datetime <- read.csv(test_path("testdata/test_tt_read_data_simple.csv"))
  df_bad_datetime$datetime[2] <- "01/01/2024 12:10"  # different format
  example_tt <- tt_read_data(
    events = df_bad_datetime,
    col_track_id = "track_id",
    col_coords = c("lon", "lat"),
    col_date_time = "datetime"
  )
  expect_s3_class(example_tt, "move2")
  expect_equal(
    example_tt$datetime[2],
    as.POSIXct("2024-01-01 12:10:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  
  # test with datetime formats starting with dd instead of yyyy
  example_tt <- tt_read_data(
    events = test_path("testdata/test_tt_read_data_diff_datetimes.csv"),
    col_track_id = "trackid",
    col_coords = c("lon", "lat"),
    col_date_time = "datetime_posix"
  )
  expect_s3_class(example_tt, "move2")
  expect_equal( # check first datetime parsed correctly
    example_tt$datetime[1],
    as.POSIXct("2008-02-12 14:30:00", format="%Y-%m-%d %H:%M:%S", tz="UTC")
  )
  expect_equal(colnames(example_tt), c("trackid", "datetime_posix", "geometry"))
  
  # check it works on separate date and time fields with different formats
  df_diff_datetime <- read.csv(test_path("testdata/test_tt_read_data_separate_datetime.csv"))
  df_diff_datetime$date <- "01/01/2024"  # different date format
  example_tt <- tt_read_data(
    events = df_diff_datetime,
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








