# Move one (or more) variable(s) from the metadata to the event data as a new column(s).

This function moves one or more columns from the metadata of a `move2`
object to the event data, adding them as new columns. This is useful
when you want to include metadata information in the event-level
analysis.

## Usage

``` r
as_event_column(x, ..., .keep = FALSE)
```

## Arguments

- x:

  A `move2` object

- ...:

  One or more unquoted column names from the metadata to move to the
  event data; it is possible to use tidyselect helpers to select
  multiple columns.

- .keep:

  A logical value indicating whether to keep the original metadata
  columns in the metadata after moving them to the event data. The
  default is `FALSE`, which means that the original metadata columns
  will be removed.

## Value

A `move2` object with the specified metadata columns added to the event
data.

## Examples

``` r
example_tt2 <- as_event_column(example_tt, sex)
example_tt2 # now showing sex in the events table
#> A <move2> with `track_id_column` "track_id" and `time_column` "date_time"
#> Containing 3 tracks lasting on average 1.33 hours in a
#> Simple feature collection with 15 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -5.5053 ymin: -1.9431 xmax: 5.5357 ymax: 3.5288
#> Geodetic CRS:  WGS 84
#> First 10 features:
#>    track_id           date_time  sex                geometry
#> 1         a 2024-01-01 12:00:00 male   POINT (1.371 -0.0627)
#> 2         a 2024-01-01 12:20:00 male   POINT (1.1694 3.5288)
#> 3         a 2024-01-01 12:40:00 male   POINT (2.2065 1.8612)
#> 4         a 2024-01-01 13:00:00 male   POINT (3.6119 2.3638)
#> 5         a 2024-01-01 13:20:00 male  POINT (5.5357 -0.5769)
#> 6         b 2024-01-01 12:00:00 male POINT (-2.4405 -1.7632)
#> 7         b 2024-01-01 12:20:00 male  POINT (-1.427 -1.9431)
#> 8         b 2024-01-01 12:40:00 male POINT (-3.3802 -0.7828)
#> 9         b 2024-01-01 13:00:00 male POINT (-0.2703 -0.3566)
#> 10        b 2024-01-01 13:20:00 male POINT (-0.9581 -1.5686)
#> To see track metadata, use `show_meta()`
```
