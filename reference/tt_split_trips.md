# Split tracks into trips for central place foragers

This function splits tracks into trips for central place foragers by
identifying the trips based on a distance from the colony/nest.

## Usage

``` r
tt_split_trips(
  x,
  centre_col = NULL,
  buffer_outbound = as_units(1000, "m"),
  buffer_inbound = as_units(1000, "m"),
  complete = TRUE
)
```

## Arguments

- x:

  A move2 object

- centre_col:

  the column name for the centre of the colony/nest of each track as
  found in the metadata table. Alternatively, an `sf` object of either
  length 1 or the same length as the number of tracks in the move2
  object. If a single geometry object is provided, it will be used as
  the centre for all tracks.

- buffer_outbound:

  the distance from the centre to define outbound trips, specified as a
  unit object, e.g `as_units(10000, "m")` or `as_units(10, "km")`.

- buffer_inbound:

  the distance from the centre to define inbound trips, specified as a
  unit object, e.g `as_units(10000, "m")` or `as_units(10, "km")`.

- complete:

  boolean, if TRUE, only complete trips (i.e. the ones that started in
  the outbound buffer and ended within the inbound buffer) are kept. If
  FALSE, all trips are kept, and events at the colony (i.e. in-between
  trips) are collected into a dummy trip labelled "trip_na".

## Value

a move2 object with the trips split.
