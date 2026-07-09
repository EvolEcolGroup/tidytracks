# Create a summary of the quality of each track

This function creates a summary of the quality of each track in a
`move2` object. It calculates the median sampling interval, track
duration, expected number of points, actual number of points, and the
proportion of expected points that are missing (due to gaps in track).

## Usage

``` r
track_summary_health(x)
```

## Arguments

- x:

  A `move2` object

## Value

A tibble with one row per track and the following columns:

- `<track id column>`: The track ID from `x`

- median_sampling_interval: The median sampling interval in seconds

- track_duration: The duration of the track in seconds

- expected_points: The expected number of points based on the median
  sampling interval

- actual_points: The actual number of points in the track

- proportion_missing: The proportion of expected points that are missing
