# Convert a `move2` object to a list of `ctmm` telemetry objects

This function converts a tibble of tracks (a `move2` object) into the
`telemetry` objects used by the package `ctmm` to fit continuous-time
movement models. One `telemetry` object is created for each track, and
the objects are returned as a list named by track id, in the same order
as the tracks in the metadata (see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md)).
The reverse conversion is provided by
[`move2::mt_as_move2()`](https://bartk.gitlab.io/move2/reference/mt_as_move2.html).

## Usage

``` r
mt_as_telemetry(x, error_cols = "auto", ...)
```

## Arguments

- x:

  A `move2` object, in a projected CRS with units in metres.

- error_cols:

  The columns of the event data with information on the error of the
  locations, to be passed to `ctmm`. If `"auto"` (the default), the
  columns with a name that `ctmm` recognises as error information (with
  Movebank naming, e.g. `gps_hdop`, `eobs_horizontal_accuracy_estimate`,
  `argos_lc`, or the time to fix `gps_time_to_fix`, used with `timeout`)
  are passed. Otherwise, a character vector of column names, or `NULL`
  to pass no error information. `ctmm` ignores columns with names that
  it does not recognise (see
  [`ctmm::as.telemetry()`](https://rdrr.io/pkg/ctmm/man/as.telemetry.html));
  such columns can be renamed by naming the vector with the names used
  by `ctmm`, e.g. `error_cols = c(HDOP = "my_hdop_column")`.

- ...:

  Additional arguments passed to
  [`ctmm::as.telemetry()`](https://rdrr.io/pkg/ctmm/man/as.telemetry.html)
  (e.g. `timeout` or `dt.hot`).

## Value

A list of `ctmm` `telemetry` objects, one per track (with at least one
location), named by track id and in the order of the metadata.

## Details

`ctmm` requires coordinates in a projected coordinate reference system
(CRS) with units in metres. If `x` is in longitude/latitude, it should
first be projected with
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html);
an appropriate CRS for the area covered by the tracks can be found with
[`crstools::suggest_crs()`](https://rdrr.io/pkg/crstools/man/suggest_crs.html).
The `telemetry` objects use the CRS of `x`, and their `x` and `y`
columns are the coordinates of `x`, so that any object estimated by
`ctmm` (e.g. a utilisation distribution) is aligned with the original
data.

Events with an empty geometry (i.e. no location) are dropped, and so are
tracks without any location.

Only the track id, time and location of each event are passed to `ctmm`
by default, plus any columns with information on location error (e.g.
GPS dilution of precision or Argos location classes) that `ctmm` can use
in an error model (see `error_cols`). Other columns are not passed as
`ctmm` identifies columns by name, so that a column such as
`tag_local_identifier` could be mistaken for the id of the track.

## Examples

``` r
# the buffalo dataset from ctmm, converted to a tibble of tracks
data(buffalo, package = "ctmm")
buffalo_tt <- mt_as_move2(buffalo)
# and converted back to a list of telemetry objects
buffalo_tel <- mt_as_telemetry(buffalo_tt)
#> Minimum sampling interval of 3 minutes in Cilla
#> Minimum sampling interval of 2 minutes in Gabs
#> Minimum sampling interval of 2 minutes in Mvubu
#> Minimum sampling interval of 3 minutes in Pepper
#> Minimum sampling interval of 2 minutes in Queen
#> Minimum sampling interval of 5 minutes in Toni
names(buffalo_tel)
#> [1] "Cilla"  "Gabs"   "Mvubu"  "Pepper" "Queen"  "Toni"  
```
