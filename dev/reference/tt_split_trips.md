# Split tracks into trips for central place foragers

This function splits tracks into trips for central place foragers, based
on when the animal moves away from, and returns to, the colony/nest (the
centre). A trip is an excursion beyond `buffer_trip`, with no minimum
duration (a single location beyond it is a trip); gaps in the data do
not split trips.

Trips are classified as complete or incomplete. If the track starts or
ends beyond `buffer_trip`, i.e. during a trip, that trip is incomplete
(e.g. the logger only started recording after the animal had left, or
its battery failed before the animal returned). So only the first and
last trips of a track can be incomplete, and a track that starts and
ends at the centre only has complete trips.

`buffer_complete` can make this check more tolerant. If it is larger
than `buffer_trip`, it is used instead, so a trip is only incomplete if
the track starts or ends beyond `buffer_complete`. For example, with
`buffer_trip` = 10 km and `buffer_complete` = 50 km, a track that starts
30 km from the centre has a complete first trip. If `buffer_complete` is
the same as, or smaller than, `buffer_trip`, it has no effect.

## Usage

``` r
tt_split_trips(
  x,
  centre_col = NULL,
  buffer_trip = as_units(1000, "m"),
  buffer_complete = as_units(1000, "m"),
  complete = TRUE,
  boundary_events = c("none", "return", "departure", "both"),
  buffer_outbound = NULL,
  buffer_inbound = NULL
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
  [`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/dev/reference/sf_point_col.md)
  can be used to create this column.

- buffer_trip:

  the distance from the centre that delimits trips: a trip starts when
  the animal moves further than this distance from the centre, and ends
  when it comes back within it. Specified as a unit object, e.g
  `as_units(10000, "m")` or `as_units(10, "km")`.

- buffer_complete:

  a distance from the centre, usually the same as or larger than
  `buffer_trip`, within which a track can start or end during a trip and
  that trip still be classified as complete (see Description). It has no
  effect if it is the same as, or smaller than, `buffer_trip`. Specified
  as a unit object, e.g `as_units(10000, "m")` or `as_units(10, "km")`.

- complete:

  boolean, if TRUE, only complete trips are kept. If FALSE, all trips
  are kept, and events at the colony (i.e. in-between trips) are
  collected into a dummy trip labelled "trip_na".

- boundary_events:

  which locations at the centre, i.e. within `buffer_trip`, are also
  included in the trips, so that the trips connect to the centre:

  - `"none"` (the default): none, trips only include the events outside
    `buffer_trip`.

  - `"return"`: each trip that ends back at the centre also includes the
    location that ends it, i.e. its first location back within
    `buffer_trip`, as the trips of `tripSplit()` in the `track2KBA`
    package do.

  - `"departure"`: each trip that does not start the track also includes
    its departure location, i.e. the last location within `buffer_trip`
    before it.

  - `"both"`: both of the above. If a single location at the centre
    separates two trips, it is the return of the earlier trip, and the
    later trip has no departure location.

  Trips that start or end the track have no departure or return
  location.

- buffer_outbound, buffer_inbound:

  Deprecated, use `buffer_trip` and `buffer_complete` instead (see
  [tidytracks-deprecated](https://evolecolgroup.github.io/tidytracks/dev/reference/tidytracks-deprecated.md)).
  The old names still work for backwards compatibility, but they issue a
  warning and will be removed in a future release.

## Value

The `move2` object, modified: each track is split into its foraging
trips, and each trip is treated as a separate track:

- The events have a new column, `trip_id`, which becomes the track id
  column. The original track id column is kept, so trips can still be
  grouped by track.

- The metadata has one row per trip, with the columns of its original
  track (repeated for each of its trips), and new columns `trip_id`
  (linking to events table `trip_id`), and `trip_type`:

  - `"complete"`: the whole trip was recorded.

  - `"incomplete"`: the track starts or ends during the trip (beyond
    `buffer_complete`, if that is larger than `buffer_trip`), so part of
    the trip is missing.

  - `"at_centre"`: not a trip, but all the events of the track at the
    centre (before, between and after its trips), in a single row per
    track.

Trips are labelled `<track id>_trip_1`, `<track id>_trip_2`, ... in time
order, and `<track id>_trip_na` for the events at the centre. With
`complete = TRUE` (the default), only complete trips are kept, so tracks
without a complete trip are dropped, and the numbering can have gaps
(e.g. if the first trip of a track is incomplete, its first trip kept is
`<track id>_trip_2`).

## Details

Events without a location (empty geometries) are assigned to the trip of
the preceding event with a location (or of the following one, at the
start of a track), so they only join a trip when they fall between two
of its events. In particular, events without a location after a return
location added by `boundary_events` stay at the centre.

## Examples

``` r
# First, add a sf point column to metadata giving nest location
show_meta(example_tt) <- show_meta(example_tt) %>%
  dplyr::mutate(nest_location = sf_point_col(nest_lon, nest_lat, crs = 4326))
# Now split the tracks into trips
example_tt_split <- tt_split_trips(
  x = example_tt,
  centre_col = "nest_location",
  buffer_trip = as_units(1, "km"),
  buffer_complete = as_units(1, "km"),
  complete = FALSE
)
# Now the unit of tracking is `trip_id` column
move2::mt_track_id_column(example_tt_split)
#> [1] "trip_id"
# Three incomplete trips were identified
show_meta(example_tt_split) %>%
  dplyr::group_by(track_id, trip_id, trip_type) %>%
  dplyr::summarise(.groups = "drop")
#> # A tibble: 5 × 3
#>   track_id trip_id   trip_type 
#>   <fct>    <chr>     <chr>     
#> 1 a        a_trip_1  incomplete
#> 2 b        b_trip_1  incomplete
#> 3 b        b_trip_na at_centre 
#> 4 c        c_trip_1  incomplete
#> 5 c        c_trip_na at_centre 
```
