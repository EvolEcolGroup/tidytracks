# Compute the cumulative Utilisation Distribution (UD)

This function takes a SpatRaster representing the UD and returns a
SpatRaster containing the cumulative utilisation distribution (UD).

## Usage

``` r
hr_cud(x)
```

## Arguments

- x:

  A SpatRaster of the UD.

## Value

A
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
representing the cumulative utilisation distribution (UD).
