# Measure the azimuth between two events

This function measures the azimuth between two events. It returns a
vector of azimuths of the same length as the number of events in `x`,
with the azimuth for the last event of each track padded with an NA.

## Usage

``` r
event_azimuth(x, units)
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
#> Units: [rad]
#>  [1] -0.05638049  2.58225137  1.22882037  2.55889282          NA  1.74569018
#>  [7] -1.03803727  1.43579575 -2.62268056          NA -1.38030523  0.82696528
#> [13]  2.42806003 -0.75928493          NA
```
