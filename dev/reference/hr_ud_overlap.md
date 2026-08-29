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
hr_ud_overlap(x, ..., method = c("ba", "vi", "udoi", "earth_mover"))

# S3 method for class 'SpatRaster'
hr_ud_overlap(
  x,
  y,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover"),
  cond_level = NULL
)

# S3 method for class 'hr_ud_tbl'
hr_ud_overlap(
  x,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover"),
  cond_level = NULL
)
```

## Arguments

- x:

  A SpatRaster of the utilisation distribution (with a layer `ud`), or a
  tibble of UDs of class `hr_ud_tbl` (e.g. as created with
  [`hr_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_kde.md)).

- ...:

  Additional arguments (not currently used)

- method:

  A character string specifying the method to use for overlap
  calculation. Options are `"ba"` (Bhattacharyya's Affinity), `"vi"`
  (Volume of Intersection), `"udoi"` (Utilisation Distribution Overlap
  Index), and `"earth_mover"` (Earth Mover's Distance). `"earth_mover"`
  returns a distance, where zero indicates identical UDs, and requires
  the suggested package `emdist`. Default is `"ba"`.

- y:

  A SpatRaster of the utilisation distribution, if `x` is a single UD.
  Else, if `x` is tibble of UDs, `y` is not used.

- cond_level:

  Optional, the level for which the the conditional overlap is computed.

## Value

A numeric value representing the overlap between the two UDs according
to the specified method, or a matrix of such values if `x` is a tibble
of multiple UDs.

## Details

When `x` is an `hr_ud_tbl`, each UD is validated, converted to cell
values, and conditionally masked once before all pairwise comparisons
are calculated. This avoids repeated raster reads and
cumulative-distribution calculations for UDs that occur in multiple
pairs.

## Examples

``` r
example_kde <- hr_kde(example_tt)
hr_ud_overlap(example_kde)
#>           a         b         c
#> a 1.0000000 0.2287909 0.1684975
#> b 0.2287909 1.0000000 0.5419589
#> c 0.1684975 0.5419589 1.0000000
```
