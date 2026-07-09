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
