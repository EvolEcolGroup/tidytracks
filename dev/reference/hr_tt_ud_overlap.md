# Compute overlap for utilisation distributions

This function computes the overlap between pairs of utilisation
distributions (UDs) using various methods. If `x` is a `SpatRaster`, it
computes the overlap between `x` and `y`. If `x` is an `hr_tt_ud_tbl`,
it computes the overlap for all unique pairs of UDs in the table. If
`cond_level` is set, it computes the conditional overlap for the
specified level, which is the overlap between the UDs estimated within a
given isopleth level (e.g. 50%) of the UD, rather than the full UD. This
can be useful for comparing the core areas of the UDs.

## Usage

``` r
hr_tt_ud_overlap(x, ..., method = c("ba", "vi", "udoi", "earth_mover"))

# S3 method for class 'SpatRaster'
hr_tt_ud_overlap(
  x,
  y,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover"),
  cond_level = NULL
)

# S3 method for class 'hr_tt_ud_tbl'
hr_tt_ud_overlap(
  x,
  ...,
  method = c("ba", "vi", "udoi", "earth_mover"),
  cond_level = NULL
)
```

## Arguments

- x:

  A SpatRaster of the utilisation distribution (with a layer `ud`), or a
  tibble of UDs of class `hr_tt_ud_tbl` (e.g. as created with
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)).

- ...:

  Additional arguments (not currently used)

- method:

  A character string specifying the method to use for overlap
  calculation. Options are `"ba"` (Bhattacharyya's Affinity), `"vi"`
  (Volume of Intersection), `"udoi"` (Utilisation Distribution Overlap
  Index, see details), and `"earth_mover"` (Earth Mover's Distance).
  `"earth_mover"` returns a distance, where zero indicates identical
  UDs, and requires the suggested package `emdist`. Default is `"ba"`.

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

When `x` is an `hr_tt_ud_tbl`, each UD is validated, converted to cell
values, and conditionally masked once before all pairwise comparisons
are calculated. This avoids repeated raster reads and
cumulative-distribution calculations for UDs that occur in multiple
pairs.

The UDOI is computed as defined by Fieberg & Kochanny (2005), as
\\A\_{1,2} \int\int UD_1(x,y) UD_2(x,y) dx dy\\, where \\A\_{1,2}\\ is
the area of overlap between the home ranges of the two animals. The home
ranges are the `cond_level` isopleths of the UDs or, if `cond_level` is
`NULL`, their 95% isopleths (as in
[`adehabitatHR::kerneloverlaphr()`](https://rdrr.io/pkg/adehabitatHR/man/kerneloverlap.html)).
The UDOI is 0 for UDs that do not overlap and 1 for two identical,
uniformly distributed UDs, and can be larger than 1 for non-uniform UDs
that overlap considerably. Unlike the other indices, the UDOI of a UD
with itself is therefore not 1, and it is reported on the diagonal of
the matrix returned for a table of UDs.

The isopleths used with `cond_level`, and for the UDOI, must contain at
least one cell of the grid: an error is given if a single cell holds
more than `cond_level` (or, for the UDOI with `cond_level = NULL`, 95%)
of a UD, as can happen on a grid that is coarse relative to the UD.

## References

Fieberg, J. & Kochanny, C.O. (2005) Quantifying home-range overlap: the
importance of the utilization distribution. Journal of Wildlife
Management, 69, 1346-1359.

## Examples

``` r
example_kde <- hr_tt_kde(example_tt)
hr_tt_ud_overlap(example_kde)
#>           a         b         c
#> a 1.0000000 0.2336369 0.1684640
#> b 0.2336369 1.0000000 0.5498266
#> c 0.1684640 0.5498266 1.0000000
```
