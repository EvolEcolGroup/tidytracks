# Combine AKDE home ranges into population home ranges

This function combines the utilisation distributions (UDs) of individual
tracks estimated with
[`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
into population-level UDs, using the methods of the package `ctmm`. If
`x` is grouped (e.g. by a variable of the metadata, such as sex or
colony, joined to the table of UDs), a population UD is estimated for
each group; otherwise, all the UDs are combined into a single population
UD.

## Usage

``` r
hr_tt_akde_pop(
  x,
  method = c("pkde", "mean"),
  tracks = NULL,
  models = NULL,
  weights = NULL,
  sample = TRUE,
  levels = NULL,
  ci_level = 0.95,
  tolerance = 0.001,
  ...
)
```

## Arguments

- x:

  A tibble of UDs estimated with
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
  (with the `ctmm` UD objects in column `ud_ctmm`), possibly grouped
  (e.g. with
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html))
  to estimate a population UD for each group. Each group must contain at
  least two UDs (but see Details: groups of at least three are
  recommended).

- method:

  The method used to combine the UDs, either `"pkde"` (the default) or
  `"mean"` (see Details).

- tracks:

  The `move2` object used to estimate the UDs with
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
  (only needed with `method = "pkde"`).

- models:

  The table of models used to estimate the UDs, as created with
  [`ctmm_tt_fit()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_fit.md)
  (only needed with `method = "pkde"`).

- weights:

  The weights of the individuals in the population UD. Either `NULL`
  (the default) for equal weights, or, with `method = "mean"`, the name
  of a numeric column of `x` with the relative weight of each UD
  (non-negative, and not all zero within a group), or, with
  `method = "pkde"`, `TRUE` to optimise the weights (see
  [`ctmm::pkde()`](https://rdrr.io/pkg/ctmm/man/akde.html); this
  requires the package `quadprog`).
  [`ctmm::pkde()`](https://rdrr.io/pkg/ctmm/man/akde.html) cannot use
  weights given by the user.

- sample:

  Logical; with `method = "mean"`, whether the tracks are a sample of a
  larger population (`TRUE`, the default) or the whole population
  (`FALSE`).

- levels:

  A vector of levels for the isopleths (i.e. contour lines), as numbers
  between 0 and 1. If `NULL` (the default), the full population UDs are
  returned; otherwise just the isopleths are returned, with the
  confidence intervals of their areas (as for
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)).

- ci_level:

  The confidence level of the confidence intervals of the home range
  areas, returned when `levels` is set. Default is 0.95.

- tolerance:

  With `method = "pkde"`, the target error of the numerical computations
  of [`ctmm::pkde()`](https://rdrr.io/pkg/ctmm/man/akde.html) (its
  `error` argument), which is also the largest probability mass of the
  population UD allowed outside the grid before the grid is extended.
  Default is 0.001.

- ...:

  Additional arguments passed to
  [`ctmm::pkde()`](https://rdrr.io/pkg/ctmm/man/akde.html) (e.g.
  `kernel`).

## Value

Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not NULL,
an `sf` tibble of class `hr_tt_poly_tbl`, with one row per group (and
level), and columns:

- the grouping variables of `x` (if `x` is grouped)

- `method`: the method used to estimate the population UD (`"pkde"` or
  `"akde_mean"`)

- `n_ud`: the number of individual UDs combined

- `dof_area`: the effective number of degrees of freedom of the
  population home range area

- `xmin`, `ymin`, `xmax`, `ymax`, `res`: the grid of the population UD
  (the grid of the individual UDs, possibly extended, see Details) If
  `levels` is NULL:

- `ud`: the population UDs, as a list-column of
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  objects

- `ud_ctmm`: the population UDs, as a list-column of `ctmm` `UD` objects
  Else, if `levels` is not NULL:

- `level`, `area`, `area_low`, `area_high` and `geometry`, as returned
  by
  [`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)

## Details

Two methods are available:

- `"pkde"` (the default): population kernel density estimation
  ([`ctmm::pkde()`](https://rdrr.io/pkg/ctmm/man/akde.html)), which
  estimates the population UD from the locations of all the tracks of a
  group, using kernels based on the movement models of the individuals.
  This requires the tracks (`tracks`) and the models (`models`) used to
  estimate the individual UDs.

- `"mean"`: the (weighted) average of the individual UDs
  ([`ctmm::mean.UD()`](https://rdrr.io/pkg/ctmm/man/mean.html)). The UD
  is the same as the one obtained with
  [`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md),
  but the `ctmm` UD object includes a population model, which is used to
  estimate the confidence intervals of the population home range area.
  With `sample = TRUE` (the default), the tracks are considered a sample
  of a larger population, and the uncertainty of the population
  distribution is taken into account.

In both cases, the uncertainty of the population home range areas
reflects the variation among individuals, and it is large for groups
with few individuals (as shown by small values of `dof_area`).

`ctmm` estimates some of the population-level parameters (e.g. the
bandwidth of the population kernels with `method = "pkde"`) with a
stochastic optimiser, so the results can differ between runs. With
`method = "pkde"`, both the population UD and the confidence intervals
of its area can differ; with `method = "mean"`, the population UD is
always the same, but the confidence intervals of its area (and
`dof_area`) can differ. Set the seed of the random number generator
(with [`set.seed()`](https://rdrr.io/r/base/Random.html)) before calling
`hr_tt_akde_pop()` to get reproducible results.

Use groups of at least three individuals: with both methods, `ctmm` fits
a population model to the movement models of the individuals, whose
parameters are poorly determined with only two individuals, so that its
optimiser can fail to converge and run for a very long time (depending
on the seed). If a call runs for much longer than expected, add
individuals to the group if possible, or try another seed.

Population kernel density estimation assumes that the individuals of a
group are a sample from a single population, whose home ranges are
distributed around a common centre (following a Gaussian distribution).
Groups of individuals in distinct areas (e.g. different colonies) should
be estimated separately (e.g. by grouping `x` by colony): pooling them
leads to a very smooth population UD, which can miss the areas used by a
minority of individuals.

All the UDs of a group must be estimated on the same grid (as is the
case for the UDs returned by a single call of
[`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
without a `bbox` for each group), and the population UD is estimated on
that grid. With `method = "pkde"`, the kernels of the population are
wider than those of the individuals, so the population UD can extend
beyond the grid of the individual UDs; in this case, the grid is
extended (by whole cells, so that it stays aligned with the original
grid, and in the same way for all groups that shared it) to contain the
population UD.

## See also

[`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
to estimate the individual UDs,
[`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)
to combine UDs from any method (without confidence intervals).

## Examples

``` r
data(buffalo, package = "ctmm")
buffalo_tt <- mt_as_move2(buffalo)
# we use a subset of three buffalo to make the example fast
buffalo_sub <- buffalo_tt %>%
  filter_by_meta(track %in% c("Cilla", "Gabs", "Mvubu")) %>%
  dplyr::group_by(track) %>%
  dplyr::slice_head(n = 100) %>%
  dplyr::ungroup()
# fitting the models and estimating the UDs take several seconds
# \donttest{
buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#> Minimum sampling interval of 59 minutes in Cilla
#> Minimum sampling interval of 57 minutes in Gabs
#> Minimum sampling interval of 59 minutes in Mvubu
buffalo_akde <- hr_tt_akde(buffalo_sub, buffalo_fit)
# population UD with population kernel density estimation (setting the seed
# for reproducible results, see Details)
set.seed(1)
buffalo_pop <- hr_tt_akde_pop(
  buffalo_akde,
  tracks = buffalo_sub,
  models = buffalo_fit
)
buffalo_pop
#> # A tibble: 1 × 10
#>   method  n_ud dof_area   xmin    ymin   xmax   ymax   res ud                
#>   <chr>  <int>    <dbl>  <dbl>   <dbl>  <dbl>  <dbl> <dbl> <named list>      
#> 1 pkde       3     7.48 22353. -12467. 55201. 14023.  118. <SpatRstr[,279,1]>
#> # ℹ 1 more variable: ud_ctmm <named list>
# or as the average of the individual UDs, with the 95% home range
set.seed(1)
hr_tt_akde_pop(buffalo_akde, method = "mean", levels = 0.95)
#> Simple feature collection with 1 feature and 12 fields
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 31162.02 ymin: -5835.655 xmax: 47414.98 ymax: 6338.74
#> Projected CRS: PROJCRS["unknown",
#>     BASEGEOGCRS["unknown",
#>         DATUM["World Geodetic System 1984",
#>             ELLIPSOID["WGS 84",6378137,298.257223563,
#>                 LENGTHUNIT["metre",1]],
#>             ID["EPSG",6326]],
#>         PRIMEM["Greenwich",0,
#>             ANGLEUNIT["degree",0.0174532925199433],
#>             ID["EPSG",8901]]],
#>     CONVERSION["unknown",
#>         METHOD["Two Point Equidistant"],
#>         PARAMETER["Latitude of 1st point",-24.2850983757726,
#>             ANGLEUNIT["degree",0.0174532925199433,
#>                 ID["EPSG",9122]]],
#>         PARAMETER["Longitude of 1st point",31.7775407470691,
#>             ANGLEUNIT["degree",0.0174532925199433,
#>                 ID["EPSG",9122]]],
#>         PARAMETER["Latitude of 2nd point",-25.024736901024,
#>             ANGLEUNIT["degree",0.0174532925199433,
#>                 ID["EPSG",9122]]],
#>         PARAMETER["Longitude of 2nd point",31.8880063438124,
#>             ANGLEUNIT["degree",0.0174532925199433,
#>                 ID["EPSG",9122]]],
#>         PARAMETER["False easting",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8806]],
#>         PARAMETER["False northing",0,
#>             LENGTHUNIT["metre",1],
#>             ID["EPSG",8807]]],
#>     CS[Cartesian,2],
#>         AXIS["(E)",east,
#>             ORDER[1],
#>             LENGTHUNIT["metre",1,
#>                 ID["EPSG",9001]]],
#>         AXIS["(N)",north,
#>             ORDER[2],
#>             LENGTHUNIT["metre",1,
#>                 ID["EPSG",9001]]]]
#> # A tibble: 1 × 13
#>   method  n_ud dof_area   xmin    ymin   xmax   ymax   res level   area area_low
#> * <chr>  <int>    <dbl>  <dbl>   <dbl>  <dbl>  <dbl> <dbl> <dbl>  [m^2]    [m^2]
#> 1 akde_…     3     7.48 22353. -12467. 55201. 14023.  118.  0.95 1.54e8   6.45e7
#> # ℹ 2 more variables: area_high [m^2], geometry <MULTIPOLYGON [m]>
# }
```
