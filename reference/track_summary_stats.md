# Compute summary statistics for each track

This function provides a set of summary statistics for each track. It is
unusual in returning a tibble of multiple variables rather than a single
vector. The summary statistics include the duration of the track, the
cumulative distance along the track, the maximum and minimum latitude
and longitude of the track, and, if a central place location is
provided, the maximum distance from that location, and the latitude and
longitude at the most distant point from that location.

## Usage

``` r
track_summary_stats(x, centre_col = NULL, units_duration = as_units(1, "days"))
```

## Arguments

- x:

  A `move2` object

- centre_col:

  The name of an sf point column (usually added with
  [`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/reference/sf_point_col.md))
  in the metadata table. If left as `NULL`, the first location of each
  track (i.e. the starting point) is used as the centre.

- units_duration:

  The units to use for the duration. Default is "days".

## Value

A tibble of summary statistics, with one row per track. The columns are:

- `<track id column>`: The track ID from `x`

- `tot_duration`: The total duration of the track in the specified units

- `tot_distance`: The total distance travelled in the track

- `max_latitude`: The maximum latitude of the track

- `min_latitude`: The minimum latitude of the track

- `max_longitude`: The maximum longitude of the track

- `min_longitude`: The minimum longitude of the track

- `max_dist_centre`: The maximum distance from the central place
  location in column `centre_col` (or the starting point)

- `lat_at_max_dist_centre`: The latitude at the point of maximum
  distance from the central place location (or the starting point)

- `lon_at_max_dist_centre`: The longitude at the point of maximum
  distance from the central place location (or the starting point)

## Details

Note that the central place location is often not part of the track.
This means that under certain circumstances (e.g. very large buffers
used in trip splitting), the total distance travelled along the track
may be shorter than the maximum distance from the central location. In
this case, you could consider either using a smaller buffer for trip
splitting, or manually adding an at-colony point at the start and end of
the track.

The units for distance, latitude, and longitude are taken from the
projection. The units for duration are specified by the `units_duration`
argument.

## Examples

``` r
track_summary_stats(example_tt)
#> # A tibble: 3 × 10
#>   track_id tot_duration tot_distance max_latitude min_latitude max_longitude
#>   <chr>             [d]          [m]        <dbl>        <dbl>         <dbl>
#> 1 a              0.0556     1174866.        3.53        -0.577         5.54 
#> 2 b              0.0556      870933.       -0.357       -1.94         -0.270
#> 3 c              0.0556      813408.        3.05         0.433        -0.784
#> # ℹ 4 more variables: min_longitude <dbl>, max_dist_centre [m],
#> #   lat_at_max_dist_centre <dbl>, lon_at_max_dist_centre <dbl>
```
