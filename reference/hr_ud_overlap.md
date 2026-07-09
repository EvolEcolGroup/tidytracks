# Compute overlap for utilisation distributions

This function computes the overlap between pairs of utilisation
distributions (UDs) using various methods. If `x` is a `SpatRaster`, it
computes the overlap between `x` and `y`. If `x` is an `hr_ud_tbl`, it
computes the overlap for all unique pairs of UDs in the table. If
`cond_level` is set, it computes the conditional overlap for the
specified level, which is the overlap between the UDs estimated within a
given isopleth level (e.g. 50%) of the UD, rather than the full UD. This
can be useful for comparing the core areas of the UDs.

## Usage

``` r
hr_ud_overlap(x, ..., method = c("ba", "vi", "udoi"))

# S3 method for class 'SpatRaster'
hr_ud_overlap(x, y, ..., method = c("ba", "vi", "udoi"), cond_level = NULL)

# S3 method for class 'hr_ud_tbl'
hr_ud_overlap(x, ..., method = c("ba", "vi", "udoi"), cond_level = NULL)
```

## Arguments

- x:

  A SpatRaster of the utilisation distribution (with a layer `ud`), or a
  tibble of UDs of class `hr_ud_tbl` (e.g. as created with
  [`hr_kde()`](https://evolecolgroup.github.io/tidytracks/reference/hr_kde.md)).

- ...:

  Additional arguments (not currently used)

- method:

  A character string specifying the method to use for overlap
  calculation. Options are `"ba"` (Bhattacharyya's Affinity), `"vi"`
  (Volume of Intersection), and `"udoi"` (Utilisation Distribution
  Overlap Index). Default is `"ba"`.

- y:

  A SpatRaster of the utilisation distribution, if `x` is a single UD.
  Else, if `x` is tibble of UDs, `y` is not used.

- cond_level:

  Optional, the level for which the the conditional overlap is computed.

## Value

A numeric value representing the overlap between the two UDs according
to the specified method, or a matrix of such values if `x` is a tibble
of multiple UDs.
