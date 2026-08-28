# Package index

## Tibble of tracks

Functions for loading, saving and displaying tibbles of tracks.

- [`tt_read_data()`](https://evolecolgroup.github.io/tidytracks/reference/tt_read_data.md)
  :

  Read data from a CSV file into a `move2` object

- [`tt_write_data()`](https://evolecolgroup.github.io/tidytracks/reference/tt_write_data.md)
  : Write a tibble of tracks to CSV files

- [`as.data.frame(`*`<move2>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/as_data_frame_move2.md)
  :

  Convert a `move2` object to a data frame

- [`show_meta()`](https://evolecolgroup.github.io/tidytracks/reference/show_meta.md)
  [`` `show_meta<-`() ``](https://evolecolgroup.github.io/tidytracks/reference/show_meta.md)
  :

  Show or set the track metadata of a `move2` object

- [`as_meta_column()`](https://evolecolgroup.github.io/tidytracks/reference/as_meta_column.md)
  : Move one (or more) variable(s) from the event data to the metadata
  as a new column(s).

- [`as_event_column()`](https://evolecolgroup.github.io/tidytracks/reference/as_event_column.md)
  : Move one (or more) variable(s) from the metadata to the event data
  as a new column(s).

- [`filter_by_meta()`](https://evolecolgroup.github.io/tidytracks/reference/filter_by_meta.md)
  : Filter the tracks based on variables from the metadata

- [`mt_as_move2(`*`<trip>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/mt_as_move2.trip.md)
  :

  Method to convert `trip` objects to `move2` objects

- [`sf_point_col()`](https://evolecolgroup.github.io/tidytracks/reference/sf_point_col.md)
  : Create a simple feature POINT geometry column

## Event functions

Functions operating on events (return an object of length \# of events).

- [`event_azimuth()`](https://evolecolgroup.github.io/tidytracks/reference/event_azimuth.md)
  : Measure the azimuth between two events
- [`event_distance()`](https://evolecolgroup.github.io/tidytracks/reference/event_distance.md)
  : Measure the distance between pairs of consecutive events within each
  track
- [`event_flag_mcconnell()`](https://evolecolgroup.github.io/tidytracks/reference/event_flag_mcconnell.md)
  : Clean data based on speed
- [`event_interval()`](https://evolecolgroup.github.io/tidytracks/reference/event_interval.md)
  : Measure the time interval between pairs of consecutive events within
  each track
- [`event_speed()`](https://evolecolgroup.github.io/tidytracks/reference/event_speed.md)
  : Return the speed of each segment between events
- [`event_time()`](https://evolecolgroup.github.io/tidytracks/reference/event_time.md)
  : Return the time of each event
- [`event_track_id()`](https://evolecolgroup.github.io/tidytracks/reference/event_track_id.md)
  : Return the track id of each event

## Track functions

Functions operating on tracks (return an object of length \# of tracks).

- [`track_duration()`](https://evolecolgroup.github.io/tidytracks/reference/track_duration.md)
  : Compute the total duration of each track
- [`track_lines()`](https://evolecolgroup.github.io/tidytracks/reference/track_lines.md)
  : Return a trajectory line for each track
- [`track_summary_health()`](https://evolecolgroup.github.io/tidytracks/reference/track_summary_health.md)
  : Create a summary of the quality of each track
- [`track_summary_stats()`](https://evolecolgroup.github.io/tidytracks/reference/track_summary_stats.md)
  : Compute summary statistics for each track

## Tibble functions

Functions operating on the full tibble (return a full tibble of tracks).

- [`tt_split_trips()`](https://evolecolgroup.github.io/tidytracks/reference/tt_split_trips.md)
  : Split tracks into trips for central place foragers

- [`tt_regular_time()`](https://evolecolgroup.github.io/tidytracks/reference/tt_regular_time.md)
  :

  Resample a `move2` track to regular time intervals by geometric
  interpolation

- [`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/reference/tt_order_time.md)
  :

  Order a `move2` object by time within each track_id

- [`tt_clean_mcconnell()`](https://evolecolgroup.github.io/tidytracks/reference/tt_clean_mcconnell.md)
  :

  Clean a `move2` object using McConnell's algorithm

- [`tt_drop_units()`](https://evolecolgroup.github.io/tidytracks/reference/tt_drop_units.md)
  : Drop units from a tibble of tracks

## Plotting

Functions to visualise movement.

- [`geom_event_path()`](https://evolecolgroup.github.io/tidytracks/reference/geom_event_path.md)
  :

  A `ggplot2` geometry to plot event steps as paths

- [`geom_event_point()`](https://evolecolgroup.github.io/tidytracks/reference/geom_event_point.md)
  :

  A `ggplot2` geometry to plot events as points

- [`geom_track_path()`](https://evolecolgroup.github.io/tidytracks/reference/geom_track_path.md)
  :

  A `ggplot2` geometry to plot tracks as paths

- [`animate_map()`](https://evolecolgroup.github.io/tidytracks/reference/animate_map.md)
  : Animate a user-built map with track paths or points

- [`autoplot(`*`<hr_ud_tbl>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/autoplot.hr_ud_tbl.md)
  : Autoplot a tibble of utilisation distributions

## Home range

Estimate home range and habitat use from movement data.

- [`hr_kde()`](https://evolecolgroup.github.io/tidytracks/reference/hr_kde.md)
  : Quantify the home range using kernel density estimation
- [`hr_mcp()`](https://evolecolgroup.github.io/tidytracks/reference/hr_mcp.md)
  : Quantify the home range using minimum convex polygon (MCP)
- [`hr_ud_iso()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_iso.md)
  : Create isopleths from utilisation distributions
- [`hr_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_overlap.md)
  : Compute overlap for utilisation distributions
- [`hr_ud_saveRDS()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_saveRDS.md)
  : Save utilisation distributions as an RDS file
- [`hr_ud_sum()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_sum.md)
  : Compute the normalised sum of multiple UDs
- [`hr_ud_unwrap()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_unwrap.md)
  : Unwrap utilisation distributions after loading
- [`hr_ud_wrap()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_wrap.md)
  : Wrap utilisation distributions for storage

## List of PackedRasters

Process lists of rasters (used to represent UDs for home ranges).

- [`PackedSpatRaster_list()`](https://evolecolgroup.github.io/tidytracks/reference/PackedSpatRaster_list.md)
  :

  Create a `PackedSpatRaster_list`

- [`as.list(`*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/as.list.PackedSpatRaster_list.md)
  :

  Unpack all rasters into a plain list of live `SpatRasters`

- [`as_PackedSpatRaster_list()`](https://evolecolgroup.github.io/tidytracks/reference/as_PackedSpatRaster_list.md)
  :

  Coerce a plain list of `SpatRasters` to `PackedSpatRaster_list`

- [`` `$`( ``*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/cash-.PackedSpatRaster_list.md)
  :

  Returns `SpatRaster` by name from `PackedSpatRaster_list`

- [`` `$<-`( ``*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/cash-set-.PackedSpatRaster_list.md)
  :

  Add `SpatRaster` by name to `PackedSpatRaster_list`

- [`print(`*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/print.PackedSpatRaster_list.md)
  :

  Print a summary of the `PackedSpatRaster_list`

- [`` `[`( ``*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/sub-.PackedSpatRaster_list.md)
  :

  Subset a `PackedSpatRaster_list` by position or name

- [`` `[[`( ``*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/sub-sub-.PackedSpatRaster_list.md)
  :

  Returns `SpatRaster` by position or name from `PackedSpatRaster_list`

- [`` `[[<-`( ``*`<PackedSpatRaster_list>`*`)`](https://evolecolgroup.github.io/tidytracks/reference/sub-subset-.PackedSpatRaster_list.md)
  :

  Add `SpatRaster` by position or name to `PackedSpatRaster_list`

## Helper functions

Helper functions to manipulate and convert data.

- [`dist_category()`](https://evolecolgroup.github.io/tidytracks/reference/dist_category.md)
  : Create a categorical distance matrix
- [`same_category()`](https://evolecolgroup.github.io/tidytracks/reference/same_category.md)
  : Create a categorical similarity matrix

## Example datasets

Example datasets for testing and demonstration.

- [`example_tt`](https://evolecolgroup.github.io/tidytracks/reference/example_tt.md)
  :

  A simple example `move2` object
