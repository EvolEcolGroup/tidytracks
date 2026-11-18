# Return the name of the track id column

This is a helper function to get the name of the column of the events
(and of the metadata) that holds the track id of each event, i.e. the
column designated "track_id_column" in the move2 object (e.g. `trip_id`
after
[`tt_split_trips()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_split_trips.md)).
To get the track id of each event, use
[`event_track_id()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_track_id.md);
to change the track id column, use
[`move2::mt_set_track_id_column()`](https://bartk.gitlab.io/move2/reference/column_name.html).

## Usage

``` r
colname_track_id(x)
```

## Arguments

- x:

  A move2 object

## Value

The name of the track id column of `x`, as a character string

## See also

[`colname_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/colname_time.md)
for the name of the time column

## Examples

``` r
colname_track_id(example_tt)
#> [1] "track_id"
```
