# Draft: move2 issue on group_by_track_data() and filter_track_data()

Draft of an upstream issue for move2, as #92 suggests, written on 16 Nov 2026
for Andrea to file (the move2 issue tracker is on GitLab, `bartk/move2`).
Before filing, rerun the example with the latest move2 (it was run with move2
0.5.0, sf 1.1.3 and dplyr 1.2.1) and update the output.

tidytracks works around these failures: `filter_by_meta()` replaces
`filter_track_data()`, and `group_by_meta()` replaces `group_by_track_data()`
(#95). Both turn an `sf` table of metadata into a plain table first.

---

**Title:** `group_by_track_data()` and `filter_track_data()` fail with columns
in both tables, or with an `sf` table of track data

Thanks for move2! We found three cases where `group_by_track_data()` or
`filter_track_data()` fail:

1. `group_by_track_data()` fails when the grouping column is already in the
   events too (e.g. after `mt_as_event_attribute(.keep = TRUE)`): the join
   renames both copies (`sex...3`, `sex...5`), and the grouping column is then
   not found.
2. `group_by_track_data()` fails when the track data is an `sf` table whose
   geometry column is named `geometry`, the default of `sf::st_as_sf()`. The
   name clashes with the geometry of the events. It works when the geometry
   of the track data has another name.
3. `filter_track_data()` fails whenever the track data is an `sf` table, whatever
   the name of its geometry column.

Also, `group_by_track_data()` copies the grouping columns into the events, so
the same information is then in both tables. Would it make sense to move them
instead, or to document that they are copied?

```r
library(move2)
library(sf)
# two tracks of three events each
x <- mt_as_move2(
  data.frame(
    track = rep(c("a", "b"), each = 3),
    time = as.POSIXct("2024-01-01", tz = "UTC") + rep(0:2, 2) * 3600,
    x = 1:6, y = 1:6
  ),
  coords = c("x", "y"), crs = 4326, time_column = "time",
  track_id_column = "track"
)
x <- mt_set_track_data(x, data.frame(track = c("a", "b"), sex = c("f", "m")))

# 1. the grouping column is in both tables
y <- mt_as_event_attribute(x, sex, .keep = TRUE)
group_by_track_data(y, sex)
#> New names:
#> • `sex` -> `sex...3`
#> • `sex` -> `sex...5`
#> Error: Must group by variables found in `.data`.
#> ✖ Column `sex` is not found.

# 2. sf track data, with its geometry named 'geometry'
meta_sf <- st_as_sf(
  data.frame(track = c("a", "b"), sex = c("f", "m"), lon = c(0, 1),
             lat = c(0, 1)),
  coords = c("lon", "lat"), crs = 4326
)
z <- mt_set_track_data(x, meta_sf)
group_by_track_data(z, sex)
#> New names:
#> • `geometry` -> `geometry...3`
#> • `geometry` -> `geometry...5`
#> Error: ℹ In argument: `all_of(to_omit)`.
#> Caused by error in `all_of()`:
#> ! Can't subset elements that don't exist.
#> ✖ Element `geometry` doesn't exist.

# 3. sf track data, with any geometry name
filter_track_data(z, sex == "f")
#> Error: All track ids in the `track_id_column` ("track") of the track data
#> frame should correspond to tracks present in the <move2> object.
st_geometry(meta_sf) <- "nest"
w <- mt_set_track_data(x, meta_sf)
group_by_track_data(w, sex) # works
filter_track_data(w, sex == "f")
#> Error: All track ids in the `track_id_column` ("track") of the track data
#> frame should correspond to tracks present in the <move2> object.

# with plain track data, both work
nrow(filter_track_data(x, sex == "f"))
#> [1] 3
```

move2 0.5.0, sf 1.1.3, dplyr 1.2.1, R 4.6.1.
