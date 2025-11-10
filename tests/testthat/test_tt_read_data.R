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

# TODO? test with different date/time field formats


# OLD TEST to use as template and then delete
test_that("tt_read_data works with valid input", {
  skip()
  # Read in the data from a csv
  example_csv <- system.file("/extdata/csv_files/dataset_example_birdlife.csv",
                                     package = "tidytracks")
  
  example_tt <- tt_read_data(albatross_csv,
                               col_track_id = "track_id",
                               col_coords = c("longitude", "latitude"),
                               col_date_time = c("date_gmt", "time_gmt"))
  
  # Check that the move2 object is created correctly
  expect_s3_class(example_tt, "move2")
  # only have date and locations as event specific variables
  expect_true(length(names(example_tt)) == 3)
  expect_true(all(c("track_id", "date_time", "geometry") %in% names(example_tt)))
  # Check that the meta data is correctly populated
  # expect that the meta data has the correct columns
  expect_true(
    all(
      c("scientific_name", "age", "breed_status") %in%
        names(show_meta(example_tt))))
  
  #@TODO we need tests for bring in a meta.csv, as well as various errors
})
