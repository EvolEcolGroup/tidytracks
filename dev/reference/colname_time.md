# Return the name of the time column

This is a helper function to get the name of the column of the events
that holds the time of each event, i.e. the column designated
"time_column" in the move2 object. To get the time of each event, use
[`event_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_time.md);
to change the time column, use
[`move2::mt_set_time_column()`](https://bartk.gitlab.io/move2/reference/column_name.html).

## Usage

``` r
colname_time(x)
```

## Arguments

- x:

  A move2 object

## Value

The name of the time column of `x`, as a character string

## See also

[`colname_track_id()`](https://evolecolgroup.github.io/tidytracks/dev/reference/colname_track_id.md)
for the name of the track id column

## Examples

``` r
colname_time(example_tt)
#> [1] "date_time"
```
