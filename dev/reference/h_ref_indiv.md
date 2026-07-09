# Compute h_ref for KDE, one value per group

This computes the reference bandwidth for the a bivariate normal kernel.

## Usage

``` r
h_ref_indiv(xy, group_index)
```

## Arguments

- xy:

  A matrix of coordinates

- group_index:

  A vector of group indices

## Value

A vector of bandwidths, one for each group
