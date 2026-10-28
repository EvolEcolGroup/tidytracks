# Fit continuous-time movement models to each track with `ctmm`

This function fits a continuous-time movement model, using the package
`ctmm`, to each track of a tibble of tracks. The fitted models are
returned in a tibble with one row per track, in the same order as the
tracks in the metadata (see
[`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md)),
so that they can be easily combined with the metadata for further
analyses. The table of models is the starting point for the analyses
that rely on `ctmm`, such as the estimation of home ranges with
autocorrelated kernel density estimation
([`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)).

## Usage

``` r
ctmm_tt_fit(
  x,
  model = "auto",
  error = FALSE,
  uere = NULL,
  ic = "AICc",
  candidates = FALSE,
  error_cols = "auto",
  cores = 1,
  ...
)
```

## Arguments

- x:

  A `move2` object, in a projected coordinate reference system with
  units in metres. It can be grouped by its track id column, but not by
  other variables (see Details).

- model:

  The movement model to fit. Either one of:

  - `"auto"` (the default): select the best model with
    [`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html),
    which starts from the model suggested by the variogram of the track
    (generally an anisotropic Ornstein-Uhlenbeck foraging process), and
    fits simpler models (e.g. isotropic, Ornstein-Uhlenbeck, or
    independent locations) until the information criterion no longer
    improves.

  - `"iid"`: independent and identically distributed locations (i.e. no
    autocorrelation).

  - `"ou"`: Ornstein-Uhlenbeck process (autocorrelated positions, with a
    home range).

  - `"ouf"`: Ornstein-Uhlenbeck foraging process (autocorrelated
    positions and velocities, with a home range).

  - `"bm"`: Brownian motion (no home range).

  - a model template created with
    [`ctmm::ctmm()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html), which
    is fitted to every track with
    [`ctmm::ctmm.fit()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html).

  - a list of such templates, one per track, either named by track id or
    in the order of the metadata.

- error:

  Logical; whether to fit a model of location error. If the tracks have
  information on the error of each location (e.g. dilution of precision,
  see `error_cols`), it is used by the error model. With a model
  template, `error = TRUE` adds the error model to the template, unless
  the template already has one (e.g. `ctmm::ctmm(error = TRUE)`); with
  `error = FALSE`, the error model of the template (if any) is kept.

- uere:

  A User Equivalent Range Error (in metres) used to calibrate the
  location error (see
  [`ctmm::uere()`](https://rdrr.io/pkg/ctmm/man/uere.html)), or an
  object created with
  [`ctmm::uere.fit()`](https://rdrr.io/pkg/ctmm/man/uere.html) from
  calibration data. If set, the error model is fitted (i.e. `error` is
  set to `TRUE`), also for model templates.

- ic:

  The information criterion used to select the best model when
  `model = "auto"` (see
  [`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html)).
  Default is `"AICc"`.

- candidates:

  Logical; if `TRUE` and `model = "auto"`, all the candidate models
  fitted by
  [`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html),
  ranked by `ic`, are returned in the list-column `candidates`. Default
  is `FALSE`.

- error_cols:

  The columns of the event data with information on the error of the
  locations, passed to
  [`mt_as_telemetry()`](https://evolecolgroup.github.io/tidytracks/dev/reference/mt_as_telemetry.md).
  The same columns are used by the other functions that use the fitted
  models.

- cores:

  The number of cores used by
  [`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html) to
  fit the candidate models in parallel (only used with
  `model = "auto"`).

- ...:

  Additional arguments passed to
  [`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html)
  (if `model = "auto"`) or
  [`ctmm::ctmm.fit()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html)
  (otherwise), e.g. `method` or `control`.

## Value

A tibble of class `ctmm_tt_fit_tbl`, with one row per track, in the
order of the metadata, and columns:

- the track id column (as named in `x`)

- `model`: a list-column of the fitted `ctmm` models (`NULL` if the
  model could not be fitted)

- `model_name`: the name of the fitted model (e.g. `"OUF anisotropic"`)

- `aicc`: the corrected Akaike Information Criterion of the fitted model

- `dof_area`: the effective number of degrees of freedom for the
  estimate of the home range area (small values, e.g. below 5-10, imply
  very uncertain home range estimates)

- `n_events`, `t_start`, `t_end`: the number of events with a location
  used to fit the model, and the time of the first and last event; these
  are used by other functions to check that the tracks have not changed
  since the models were fitted

- `fit_message`: `NA`, or the error message if the model could not be
  fitted

- `candidates` (only if `candidates = TRUE`): a list-column of the
  candidate models

The coordinate reference system of `x`, the error columns and the `uere`
used are stored as attributes of the table.

## Details

Fitting is done in two steps, as recommended by `ctmm`: first, initial
values of the parameters are guessed from the empirical variogram of
each track
([`ctmm::ctmm.guess()`](https://rdrr.io/pkg/ctmm/man/variogram.fit.html)),
and then the model is fitted by maximum likelihood
([`ctmm::ctmm.fit()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html)). With
`model = "auto"` (the default), a series of candidate models is fitted
and the best one is selected based on an information criterion
([`ctmm::ctmm.select()`](https://rdrr.io/pkg/ctmm/man/ctmm.fit.html)).
This is the most appropriate approach in most cases, but it can be slow
for long tracks. It is always good practice to inspect the fit of the
models (e.g. by comparing the variogram of each track with the fitted
model, see the "Movement models with ctmm" article).

Models are fitted to each track separately. To fit models at a different
level (e.g. to each trip, or to each season of a track), first make that
level the track of `x`, e.g. with
[`tt_split_trips()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_split_trips.md)
or
[`move2::mt_set_track_id()`](https://bartk.gitlab.io/move2/reference/mt_track_id.html).

The track data are converted with
[`mt_as_telemetry()`](https://evolecolgroup.github.io/tidytracks/dev/reference/mt_as_telemetry.md),
so `x` must be in a projected coordinate reference system with units in
metres (see
[`mt_as_telemetry()`](https://evolecolgroup.github.io/tidytracks/dev/reference/mt_as_telemetry.md)
for details).

If the model cannot be fitted for a track (e.g. because the track has
too few locations), a warning is given, and the track is kept in the
table with a `NULL` model, and the error message in column
`fit_message`, so that the table always has one row per track in the
metadata. Warnings raised by `ctmm` while fitting are reported with the
id of the track.

## See also

[`ctmm_tt_summary()`](https://evolecolgroup.github.io/tidytracks/dev/reference/ctmm_tt_summary.md)
to summarise the parameters of the models,
[`hr_tt_akde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_akde.md)
to estimate home ranges from the models.

## Examples

``` r
# the buffalo dataset from ctmm, converted to a tibble of tracks
data(buffalo, package = "ctmm")
buffalo_tt <- mt_as_move2(buffalo)
# we use a subset of the first two buffalo to make the example fast
buffalo_sub <- buffalo_tt %>%
  filter_by_meta(track %in% c("Cilla", "Gabs")) %>%
  dplyr::group_by(track) %>%
  dplyr::slice_head(n = 100) %>%
  dplyr::ungroup()
# fitting the models takes a few seconds
# \donttest{
buffalo_fit <- ctmm_tt_fit(buffalo_sub, model = "ou")
#> Minimum sampling interval of 59 minutes in Cilla
#> Minimum sampling interval of 57 minutes in Gabs
buffalo_fit
#> # A tibble: 2 × 9
#>   track model        model_name      aicc dof_area n_events t_start            
#>   <fct> <named list> <chr>          <dbl>    <dbl>    <int> <dttm>             
#> 1 Cilla <ctmm>       OU anisotropic 3114.     3.29      100 2005-07-14 05:35:00
#> 2 Gabs  <ctmm>       OU anisotropic 2875.     1.68      100 2005-04-05 05:56:00
#> # ℹ 2 more variables: t_end <dttm>, fit_message <chr>
# }
```
