# Compute summary statistics for each track

This function provides a set of summary statistics for each track. It is
unusual in returning a tibble of multiple variables rather than a single
vector. The summary statistics include the duration of the track, the
cumulative distance, the maximum and minimum latitude and longitude of
the total track, and, if a central place location is provided, the
maximum distance that location, and the latitude at the most distant
point from the central place location

## Usage

``` r
track_summary_stats(x, centre_col = NULL, units_duration = as_units(1, "days"))
```

## Arguments

- x:

  A `move2` object

- centre_col:

  The name of an sf point column (usually added with
  [`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/dev/reference/sf_point_col.md))
  in the metadata table. If left to NULL, the first location (i.e. the
  starting point) is used at the centre.

- units_duration:

  The units to use for the duration. Default is "days".

## Value

A tibble of summary statistics, with one row per track. The columns are:

- `<track id column>`: The track ID from `x`

- tot_duration: The total duration of the track in the specified units

- tot_distance: The total distance travelled in the track in metres

- max_latitude: The maximum latitude of the track

- min_latitude: The minimum latitude of the track

- max_longitude: The maximum longitude of the track

- min_longitude: The minimum longitude of the track

- max_dist_centre: The maximum distance from the central place location
  in column `centre_col` (or the starting point) in metres

- lat_at_max_dist_centre: The latitude at the point of maximum distance
  from the central place location (or the starting point))

- lon_at_max_dist_centre: The longitude at the point of maximum distance
  from the central place location (or the starting point)
