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

  character string, the name of the column in the metadata table that
  contains the centre of the colony/nest for each track. This column
  must be of class `sfc_POINT` and should have a valid coordinate
  reference system (CRS) specified. The function
  [`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/reference/sf_point_col.md)
  can be used to create this column.

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
