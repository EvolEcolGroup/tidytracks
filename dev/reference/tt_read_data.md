# Read data from a CSV file into a `move2` object

This function reads a CSV file containing event data (and possibly
metadata) and converts it into a `move2` object. The CSV file should
contain contain at least the following columns:

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
  date-time. If `NULL` (default), a set of common formats will be tried:
  a date in ISO format (`%Y-%m-%d`, `%Y/%m/%d`), DMY format (`%d/%m/%Y`,
  `%d-%m-%Y`, `%d/%m/%y`, `%d-%m-%y`), or MDY format (`%m/%d/%Y`,
  `%m-%d-%Y`, `%m/%d/%y`, `%m-%d-%y`), followed by a time in `%H:%M:%OS`
  or `%H:%M`. DMY formats are tried before MDY formats, so a date that
  is ambiguous between the two (e.g. `"03/04/2024"`, where both day and
  month are valid as either) will be silently parsed as DMY (4 March
  2024), not MDY (3 April 2024). If your dates are in MDY format and
  could be ambiguous, specify `format_date_time` explicitly rather than
  relying on auto-detection. For help with specifying date-time formats,
  see [`?strptime`](https://rdrr.io/r/base/strptime.html).

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

This function makes a number of assumptions about the data. If your data
does not meet these assumptions, you may need to preprocess it before
using this function, or create a `move2` object manually using the
[`move2::mt_as_move2()`](https://bartk.gitlab.io/move2/reference/mt_as_move2.html)
function. See the article "Reading and cleaning data" on the package
website for more details, including how to read date-times in different
formats.

## Examples

``` r
small_example_csv <- system.file("extdata", "small_example.csv",
  package = "tidytracks"
)
small_example_read <- tt_read_data(small_example_csv,
  col_track_id = "track_id",
  col_coords = c("lon", "lat"),
  col_date_time = "date_time"
)
small_example_read
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.33 hours in a
#> Simple feature collection with 15 features and 2 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    track_id           date_time                geometry
#> 1         a 2024-01-01 12:00:00   POINT (1.371 -0.0627)
#> 2         a 2024-01-01 12:20:00   POINT (1.1694 3.5288)
#> 3         a 2024-01-01 12:40:00   POINT (2.2065 1.8612)
#> 4         a 2024-01-01 13:00:00   POINT (3.6119 2.3638)
#> 5         a 2024-01-01 13:20:00  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 POINT (-2.4405 -1.7632)
#> 7         b 2024-01-01 12:20:00  POINT (-1.427 -1.9431)
#> 8         b 2024-01-01 12:40:00 POINT (-3.3802 -0.7828)
#> 9         b 2024-01-01 13:00:00 POINT (-0.2703 -0.3566)
#> 10        b 2024-01-01 13:20:00 POINT (-0.9581 -1.5686)
#> Track features:
#>   track_id    sex nest_lon nest_lat
#> 1        a   male     1.37     0.06
#> 2        b   male    -2.44    -1.76
#> 3        c female    -0.78     0.43
```
