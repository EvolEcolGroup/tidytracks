# Read data from a CSV file into a `move2` object

This function reads a CSV file containing event data (and possibly
metadata) and converts it into a `move2` object. The CSV file should
contain contain at least the following columns:

## Usage

``` r
tt_read_data(
  events,
  col_track_id,
  col_coords,
  col_date_time,
  format_date_time = NULL,
  crs = 4326,
  time_zone = "UTC",
  convert_meta = TRUE,
  meta = NULL
)
```

## Arguments

- events:

  A path to a CSV file containing the event data, OR a dataframe in R
  containing the event data.

- col_track_id:

  The name of the column in the CSV file that contains the track id.

- col_coords:

  A vector of the x and y coordinate column names in the CSV file.

- col_date_time:

  The name of the column in the CSV file that contains the date-time
  information (or a vector of two elements, the names of separate date
  and time columns). Time is assumed to be in UTC.

- format_date_time:

  optional, a string containing the format of the date-time field(s):
  either the single date-time column, or the date and time columns
  separated by a space, for
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) to parse the
  date-time. If `NULL` (default), a set of common formats will be tried.
  For help with specifying date-time formats, see
  [`?strptime`](https://rdrr.io/r/base/strptime.html).

- crs:

  a proj4 string or EPSG code defining the coordinate reference system
  of the data. Defaults to `4326` (WGS 84).

- time_zone:

  a character string specifying the time zone of the date-time. Defaults
  to `"UTC"`.

- convert_meta:

  a boolean on whether to attempt to transfer information in the events
  table that is track specific (e.g. bird id or colony coordinates) to
  the meta data table. Defaults to `TRUE`.

- meta:

  A path to a csv file containing the meta data, OR a dataframe in R
  containing the metadata. If provided, this will be used to populate
  the meta data table. It needs to have a column with the track ids
  which includes all the track ids in the events table (additional track
  ids will be discarded). If a column exists in both the events table
  and the metadata table, the values will be compared: when identical,
  the duplicate is removed; when values conflict, both versions are
  retained with a '.meta' suffix added to the metadata version.

## Value

A `move2` object containing the event data.

## Details

- one column which is the `track_id` (i.e. the variable that groups
  events into a track)

- two columns representing the x and y coordinates (e.g. longitude and
  latitude)

- a date-time column (or separate date and time columns)

Additional columns of data will be stored in the events table if they
have information that is specific to each event (i.e. the values are not
unique within a given track), or they will be moved to the meta data
table if they are track specific (e.g. bird_id, sex of the individual,
colony coordinates, breeding status, etc.).

This function makes a number of assumptions about the data. If your data
does not meet these assumptions, you may need to preprocess it before
using this function, or create a `move2` object manually using the
[`move2::mt_as_move2()`](https://bartk.gitlab.io/move2/reference/mt_as_move2.html)
function. See the `reading_data` vignette for more details.

## Examples

``` r
example_events_csv <- system.file("/extdata/csv_files/dataset_example_birdlife.csv",
  package = "tidytracks"
)
example_tt <- tt_read_data(example_events_csv,
  col_track_id = "track_id",
  col_coords = c("longitude", "latitude"),
  col_date_time = c("date_gmt", "time_gmt")
)
```
