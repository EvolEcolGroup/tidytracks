# A simple example `move2` object

A very simple dataset of 3 individuals, with 5 observations per
individual, used for examples in the package documentation.

## Usage

``` r
example_tt
```

## Format

A move2 object with 15 events from 3 tracks (one per individual). We
have 3 columns in the main events table

- track_id:

  ids of each track

- date_time:

  time stamp for each event

- geometry:

  longitudes and latitudes, as an `sf` geometry for each event

And a metadata table with 3 rows (one per track) and 4 columns:

- track_id:

  ids of each track

- sex:

  sex of each individual

- nest_lon:

  longitude of the nest of each individual

- nest_lat:

  latitude of the nest of each individual
