# Measure the azimuth between two events

This function measures the azimuth between two events. It returns a
vector of azimuths of the same length as the number of events in `x`,
with the azimuth for the last event of each track padded with an NA. The
azimuth is also NA for the segments to and from events without a
location (empty geometry).

## Usage

``` r
event_azimuth(x, units = "degrees")
```

## Arguments

- x:

  A move2 object

- units:

  Optional, the units to use for the azimuth (e.g., "degrees" or
  "radians"). The default is "degrees".

## Value

a vector of azimuths of the same length as the number of events in `x`,
with the last value set to NA for each track.

## Examples

``` r
event_azimuth(example_tt)
#> Linking to GEOS 3.12.1, GDAL 3.8.4, PROJ 9.4.0; sf_use_s2() is TRUE
#> Units: [°]
#>  [1]   -3.230364  147.952105   70.406221  146.613759          NA  100.020680
#>  [7]  -59.475154   82.265037 -150.268527          NA  -79.085664   47.381620
#> [13]  139.117592  -43.503822          NA
```
