# Convert a `move2` object to a data frame

This function converts a `move2` object into a data frame, including the
event data and the associated metadata. The resulting data frame will
have one row per event, with columns for the event attributes, the track
ID, and the metadata attributes (unless `include_meta` is set to
`FALSE`).

## Usage

``` r
# S3 method for class 'move2'
as.data.frame(x, ..., include_meta = FALSE, drop_geometry = FALSE)
```

## Arguments

- x:

  A `move2` object

- ...:

  additional arguments to be passed to or from methods.

- include_meta:

  Logical, whether to include the metadata attributes in the resulting
  data frame. Default is FALSE.

- drop_geometry:

  Logical, whether to drop the geometry column from the resulting data
  frame. Default is FALSE. If TRUE, the coordinates are stored in
  separate columns (`X` and `Y`).

## Value

A data frame with one row per event, including event attributes, the
track ID, and optionally metadata attributes.

## Examples

``` r
# example code
as.data.frame(example_tt, include_meta = TRUE, drop_geometry = TRUE)
#>    track_id           date_time    sex nest_lon nest_lat       X       Y
#> 1         a 2024-01-01 12:00:00   male     1.37     0.06  1.3710 -0.0627
#> 2         a 2024-01-01 12:20:00   male     1.37     0.06  1.1694  3.5288
#> 3         a 2024-01-01 12:40:00   male     1.37     0.06  2.2065  1.8612
#> 4         a 2024-01-01 13:00:00   male     1.37     0.06  3.6119  2.3638
#> 5         a 2024-01-01 13:20:00   male     1.37     0.06  5.5357 -0.5769
#> 6         b 2024-01-01 12:00:00   male    -2.44    -1.76 -2.4405 -1.7632
#> 7         b 2024-01-01 12:20:00   male    -2.44    -1.76 -1.4270 -1.9431
#> 8         b 2024-01-01 12:40:00   male    -2.44    -1.76 -3.3802 -0.7828
#> 9         b 2024-01-01 13:00:00   male    -2.44    -1.76 -0.2703 -0.3566
#> 10        b 2024-01-01 13:20:00   male    -2.44    -1.76 -0.9581 -1.5686
#> 11        c 2024-01-01 12:00:00 female    -0.78     0.43 -0.7845  0.4328
#> 12        c 2024-01-01 12:20:00 female    -0.78     0.43 -4.0496  1.0655
#> 13        c 2024-01-01 12:40:00 female    -0.78     0.43 -3.8075  1.2897
#> 14        c 2024-01-01 13:00:00 female    -0.78     0.43 -3.4103  0.8278
#> 15        c 2024-01-01 13:20:00 female    -0.78     0.43 -5.5053  3.0464
```
