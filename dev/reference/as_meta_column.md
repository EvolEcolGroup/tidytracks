# Move one (or more) variable(s) from the event data to the metadata as a new column(s).

This function moves one or more columns from the event data of a `move2`
object to the metadata, adding them as new columns. This is useful when
you want to include event-level information in the metadata. Note that
all events for a given track must have the same value for the variable
being moved to metadata.

## Usage

``` r
as_meta_column(x, ..., .keep = FALSE)
```

## Arguments

- x:

  A `move2` object

- ...:

  One or more unquoted column names from the event data to move to the
  metadata; it is possible to use tidyselect helpers to select multiple
  columns.

- .keep:

  A logical value indicating whether to keep the original event data
  columns in the event data after moving them to the metadata. The
  default is `FALSE`, which means that the original event data columns
  will be removed.

## Value

A `move2` object with the specified event data columns added to the
metadata.

## Examples

``` r
# we first move the sex column to the event data
example_tt2 <- as_event_column(example_tt, sex)
# and now we move it back to the metadata
example_tt2 <- as_meta_column(example_tt2, sex)
show_meta(example_tt2)
#>   track_id nest_lon nest_lat    sex
#> 1        a     1.37     0.06   male
#> 2        b    -2.44    -1.76   male
#> 3        c    -0.78     0.43 female
```
