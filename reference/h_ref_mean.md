# Compute h_ref for KDE, returning the mean value

This computes the reference bandwidth for the a bivariate normal kernel.

## Usage

``` r
h_ref_mean(xy, group_index)
```

## Arguments

- xy:

  A matrix of coordinates

- group_index:

  A vector of group indices

## Value

A single value, the mean of the bandwidths for each group
