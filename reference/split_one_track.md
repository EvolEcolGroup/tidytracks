# Split a track into trips

an internal function that works on single tracks

## Usage

``` r
split_one_track(
  label,
  x,
  y,
  is_lonlat,
  centre_x,
  centre_y,
  buffer_outbound,
  buffer_inbound
)
```

## Arguments

- label:

  the label for the track

- x:

  the x coordinates

- y:

  the y coordinates

- is_lonlat:

  a logical indicating if the coordinates are in lonlat

- centre_x:

  the x coordinate for the central place (e.g. colony, nest)

- centre_y:

  the y coordinate for the central place (e.g. colony, nest)

- buffer_outbound:

  the buffer for outbound trips

- buffer_inbound:

  the buffer for inbound trips

## Value

a vector with trip IDs for each event (events to remove are marked as
NA)
