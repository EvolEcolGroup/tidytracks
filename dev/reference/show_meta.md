# Show or set the track metadata of a `move2` object

The track metadata is stored as a data frame within the `move2` object.
This function allows you to view or modify this metadata. When
retrieving the metadata, it returns a tibble containing the metadata for
each track. When setting the metadata, you can provide a new data frame
with the updated metadata, or modify or remove specific columns, as you
would normally do with a data.frame/tibble. If providing a new metadata
table, make sure that the number of rows matches the number of tracks in
the `move2` object, and that the track IDs correspond to those in the
`move2` object.

## Usage

``` r
show_meta(x)

show_meta(x) <- value
```

## Arguments

- x:

  A move2 object

- value:

  A data frame with metadata to set for the `move2` object

## Value

The metadata table from the input `move2` object (nothing is returned if
using the setter function).

## Details

Locations in the metadata (e.g. of a colony) are best stored as `sfc`
columns of a plain table (see
[`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/dev/reference/sf_point_col.md)).
An `sf` table of metadata is stored as a plain table, with its geometry
kept as an `sfc` column, as move2 cannot join an `sf` table to the
events (e.g. in
[`as_event_column()`](https://evolecolgroup.github.io/tidytracks/dev/reference/as_event_column.md)).
A metadata column with the same name as the geometry column of the
events (e.g. `geometry`, the default name of the geometry of an `sf`
table) would replace it when joined to the events, so it is renamed with
a `.meta` suffix (e.g. `geometry.meta`), with a message.

The only column that the events and the metadata should share is the
track id. When setting the metadata, a column that is also in the events
is removed from the events if it has the same values (for the events of
each track), as it is information about the tracks; if the events are
grouped by it, it is removed from the metadata instead. A column with
different values (e.g. that varies within tracks) is kept in both
tables, with the version in the metadata renamed with a `.meta` suffix,
with a warning. (To make another column the track id with
[`move2::mt_set_track_id_column()`](https://bartk.gitlab.io/move2/reference/column_name.html),
which needs it in both tables, add it to the events after setting the
metadata.)

## Examples

``` r
show_meta(example_tt)
#>   track_id    sex nest_lon nest_lat
#> 1        a   male     1.37     0.06
#> 2        b   male    -2.44    -1.76
#> 3        c female    -0.78     0.43
show_meta(example_tt)$age <- c(2, 3, 2)
show_meta(example_tt)
#>   track_id    sex nest_lon nest_lat age
#> 1        a   male     1.37     0.06   2
#> 2        b   male    -2.44    -1.76   3
#> 3        c female    -0.78     0.43   2
```
