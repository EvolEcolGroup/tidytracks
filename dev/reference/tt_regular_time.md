# Resample a `move2` track to regular time intervals by geometric interpolation

Resamples one or more tracks stored in a `move2` object onto a regular
time grid. A new grid point is placed every `interval` time units from
the start of the track. Tracks are processed independently, so different
tracks may have different temporal extents and the points from different
tracks will not have matching time stamps (as the starting points are
different).

## Usage

``` r
tt_regular_time(x, interval, max_time_lag = NULL, snap_times = FALSE)
```

## Arguments

- x:

  A `move2` object. Timestamps (as returned by
  [`event_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/event_time.md))
  must be [base::POSIXct](https://rdrr.io/r/base/DateTimeClasses.html).

- interval:

  Resampling interval as a
  [`units::units`](https://r-quantities.github.io/units/reference/units.html)
  object carrying time units convertible to seconds (e.g.
  `as_units(60, "s")`, `as_units(1, "min")`, `as_units(0.5, "h")`).
  Every track is resampled at this cadence between its own first and
  last observation. Passing a plain numeric value raises an error to
  prevent silent unit mismatches.

- max_time_lag:

  Optional upper bound on interpolation gaps, supplied as a
  [`units::units`](https://r-quantities.github.io/units/reference/units.html)
  object with time units convertible to seconds (same rules as
  `interval`). Grid points that fall strictly inside a gap between
  consecutive input observations that is *longer* than `max_time_lag`
  are silently dropped from the output. Pass `NULL` (the default) to
  interpolate across all gaps regardless of size.

- snap_times:

  Logical (default `FALSE`). When `TRUE`, each track's grid begins at
  the first whole-interval boundary that is strictly after the track's
  first observation, rather than at the first observation itself. For
  example, with `interval = 10 min`, a track starting at 08:04 will have
  its first resampled point at 08:10, then 08:20, 08:30, and so on. This
  aligns grids across tracks that share the same epoch, so that
  overlapping tracks will have identical timestamps at each step.

## Value

A `move2` object on a regular time grid. The CRS, time-column name,
track-id column name, and track-level attributes of `x` are all
preserved.

## Spatial interpolation

Positions are linearly interpolated along the observed path, with a
strategy dependent on the map projection (using a strategy similar to
[`move2::mt_interpolate()`](https://bartk.gitlab.io/move2/reference/mt_interpolate.html)):

- **No CRS** –
  [`sf::st_line_sample()`](https://r-spatial.github.io/sf/reference/st_line_sample.html)
  is called on the Euclidean linestring connecting the observations.

- **Geographic CRS (lon/lat)** – the path is treated as a spherical
  polyline and
  [`s2::s2_interpolate_normalized()`](https://r-spatial.github.io/s2/reference/s2_interpolate.html)
  is used, which follows great-circle arcs between consecutive points.

- **Projected CRS** – the track is temporarily transformed to WGS 84
  (EPSG:4326) for spherical interpolation via
  [`s2::s2_interpolate_normalized()`](https://r-spatial.github.io/s2/reference/s2_interpolate.html),
  then the resulting points are transformed back to the original CRS.

## Temporal-to-spatial mapping

Raw observations are often unevenly spaced in both time and space.
`tt_regular_time` accounts for this by first computing the normalised
arc-length fraction of every input point along the path (using
[`s2::s2_distance()`](https://r-spatial.github.io/s2/reference/s2_is_collection.html)
for geographic CRS and Euclidean distance otherwise), then using
[`stats::approx()`](https://rdrr.io/r/stats/approxfun.html) to linearly
interpolate those fractions at each new time step. A stationary stretch
of the track (many observations covering little distance) is therefore
correctly treated as slow movement, not as a spatial shortcut.

## Attribute interpolation

Numeric event-level columns are linearly interpolated at the new time
steps using [`stats::approx()`](https://rdrr.io/r/stats/approxfun.html).
Non-numeric columns receive the value of the nearest preceding
observation via
[`findInterval`](https://rdrr.io/r/base/findInterval.html). Track-level
attributes stored in
[`mt_track_data`](https://bartk.gitlab.io/move2/reference/mt_track_data.html)
are preserved unchanged.

## See also

[`mt_interpolate`](https://bartk.gitlab.io/move2/reference/mt_interpolate.html)
for the move2 implementation of the same spatial strategy with flexible
time targets (including interpolating to specific missing timestamps);
[`units::as_units()`](https://r-quantities.github.io/units/reference/units.html)
for constructing the required `units` objects;
[`sf::st_line_sample()`](https://r-spatial.github.io/sf/reference/st_line_sample.html)
for Euclidean path sampling;
[`s2::s2_interpolate_normalized()`](https://r-spatial.github.io/s2/reference/s2_interpolate.html)
for spherical arc sampling.

## Examples

``` r
library(sf)

# Build a simple three-point track with irregular time gaps
times <- as.POSIXct("2024-01-01 00:00:00", tz = "UTC") + c(5, 90, 200)
geom <- st_sfc(
  st_point(c(-0.10, 51.50)),
  st_point(c(-0.05, 51.52)),
  st_point(c(0.00, 51.54)),
  crs = 4326
)
track <- move2::mt_as_move2(
  sf::st_sf(
    timestamp = times,
    speed_ms  = c(2.1, 3.4, 1.8),
    track_id  = "gull_01",
    geometry  = geom
  ),
  time_column = "timestamp",
  track_id_column = "track_id"
)

# Resample to one fix per minute
resampled <- tt_regular_time(track, interval = as_units(1, "min"))
resampled
#> A <move2> with `track_id_column` "track_id" and `time_column` "timestamp"
#> Containing 1 track lasting 3 mins in a
#> Simple feature collection with 4 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -0.1 ymin: 51.5 xmax: -0.006820769 ymax: 51.53727
#> Geodetic CRS:  WGS 84
#>             timestamp track_id speed_ms                      geometry
#> 1 2024-01-01 00:00:05  gull_01 2.100000             POINT (-0.1 51.5)
#> 2 2024-01-01 00:01:05  gull_01 3.017647  POINT (-0.06471044 51.51412)
#> 3 2024-01-01 00:02:05  gull_01 2.890909  POINT (-0.03409567 51.52637)
#> 4 2024-01-01 00:03:05  gull_01 2.018182 POINT (-0.006820769 51.53727)
#> To see track metadata, use `show_meta()`

# Resample to 30-second fixes, skipping gaps > 2 minutes
resampled_gapped <- tt_regular_time(
  track,
  interval     = as_units(30, "s"),
  max_time_lag = as_units(2, "min")
)
resampled_gapped
#> A <move2> with `track_id_column` "track_id" and `time_column` "timestamp"
#> Containing 1 track lasting 3 mins in a
#> Simple feature collection with 7 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -0.1 ymin: 51.5 xmax: -0.006820769 ymax: 51.53727
#> Geodetic CRS:  WGS 84
#>             timestamp track_id speed_ms                      geometry
#> 1 2024-01-01 00:00:05  gull_01 2.100000             POINT (-0.1 51.5)
#> 2 2024-01-01 00:00:35  gull_01 2.558824  POINT (-0.08235795 51.50706)
#> 3 2024-01-01 00:01:05  gull_01 3.017647  POINT (-0.06471044 51.51412)
#> 4 2024-01-01 00:01:35  gull_01 3.327273  POINT (-0.04772823 51.52091)
#> 5 2024-01-01 00:02:05  gull_01 2.890909  POINT (-0.03409567 51.52637)
#> 6 2024-01-01 00:02:35  gull_01 2.454545  POINT (-0.02045986 51.53182)
#> 7 2024-01-01 00:03:05  gull_01 2.018182 POINT (-0.006820769 51.53727)
#> To see track metadata, use `show_meta()`

# Resample to one fix per minute, snapping times to whole-minute boundaries
resampled_snap <- tt_regular_time(track,
  interval = as_units(1, "min"),
  snap_times = TRUE
)
resampled_snap
#> A <move2> with `track_id_column` "track_id" and `time_column` "timestamp"
#> Containing 1 track lasting 2 mins in a
#> Simple feature collection with 3 features and 3 fields
#> Geometry type: POINT
#> Dimension:     XY
#> Bounding box:  xmin: -0.06765207 ymin: 51.51294 xmax: -0.009094177 ymax: 51.53637
#> Geodetic CRS:  WGS 84
#>             timestamp track_id speed_ms                      geometry
#> 1 2024-01-01 00:01:00  gull_01 2.941176  POINT (-0.06765207 51.51294)
#> 2 2024-01-01 00:02:00  gull_01 2.963636  POINT (-0.03636799 51.52546)
#> 3 2024-01-01 00:03:00  gull_01 2.090909 POINT (-0.009094177 51.53637)
#> To see track metadata, use `show_meta()`
```
