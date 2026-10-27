# Summarise the parameters of the movement models fitted with `ctmm`

This function extracts the estimates of the parameters of the movement
models fitted with
[`ctmm_tt_fit()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_fit.md),
with their confidence intervals (as given by
[`summary()`](https://rdrr.io/r/base/summary.html) on each model, see
[`ctmm::summary.ctmm()`](https://rdrr.io/pkg/ctmm/man/summary.ctmm.html)).
The table has one row per track, in the same order as the table of
models (and thus of the metadata), so that it can be easily joined with
the metadata (e.g. to compare home range sizes between sexes).

## Usage

``` r
ctmm_tt_summary(x, level = 0.95)
```

## Arguments

- x:

  A table of models created with
  [`ctmm_tt_fit()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_fit.md).

- level:

  The confidence level of the intervals (default 0.95).

## Value

A tibble with one row per track, and columns:

- the track id column (as in `x`)

- `model_name`: the name of the model

- `dof_area`: the effective number of degrees of freedom for the area

- for each parameter (e.g. `area`, `tau_position`, `tau_velocity`,
  `speed`, `diffusion`), three columns with the lower bound of the
  confidence interval (`_low`), the estimate (`_est`) and the upper
  bound (`_high`)

## Details

The parameters depend on the models: e.g. models without autocorrelation
(`"IID"`) only have an `area`, Ornstein-Uhlenbeck models (`"OU"`) also
have a time scale of the autocorrelation of positions (`tau_position`,
the home range crossing time), and Ornstein-Uhlenbeck foraging models
(`"OUF"`) also have a time scale of the autocorrelation of velocities
(`tau_velocity`), and estimates of `speed`. The table has columns for
all the parameters estimated for any track, and `NA` for the tracks
whose model does not estimate a parameter.

Note that `area` is the area of the Gaussian home range of the model (at
the 95% level), which is not the same as the home range estimated with
[`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
(which uses the model to estimate the utilisation distribution
non-parametrically).

The values are returned as `units` objects in SI units (e.g. m^2 for
areas, seconds for time scales); they can be converted to more
convenient units with
[`units::set_units()`](https://r-quantities.github.io/units/reference/units.html)
(e.g. `units::set_units(area_est, km^2)`).

## See also

[`ctmm_tt_fit()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_fit.md)
to fit the models.

## Examples

``` r
data(buffalo, package = "ctmm")
buffalo_tt <- mt_as_move2(buffalo)
# we use a subset of the first two buffalo to make the example fast
buffalo_sub <- buffalo_tt %>%
  filter_by_meta(track %in% c("Cilla", "Gabs")) %>%
  dplyr::group_by(track) %>%
  dplyr::slice_head(n = 100) %>%
  dplyr::ungroup()
buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#> Minimum sampling interval of 59 minutes in Cilla
#> Minimum sampling interval of 57 minutes in Gabs
ctmm_tt_summary(buffalo_fit)
#> # A tibble: 2 × 12
#>   track model_name     dof_area  area_low  area_est  area_high tau_position_low
#>   <fct> <chr>             <dbl>     [m^2]     [m^2]      [m^2]              [s]
#> 1 Cilla OU anisotropic     3.29 22314822. 98190269. 229207954.           25886.
#> 2 Gabs  OU anisotropic     1.68  8261025. 91503637. 272347023.           33010.
#> # ℹ 5 more variables: tau_position_est [s], tau_position_high [s],
#> #   diffusion_low [m^2/s], diffusion_est [m^2/s], diffusion_high [m^2/s]
```
