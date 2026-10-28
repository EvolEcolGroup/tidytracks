# Quantify the home range using dynamic Brownian bridges

These functions estimate the utilisation distribution (UD) of each track
with a dynamic Brownian bridge movement model (dBBMM, Kranstauber et al.
2012) or a dynamic bivariate Gaussian bridge (dBGB, Kranstauber et al.
2014). Unlike
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md),
which treats locations as independent, bridges model the movement
between consecutive locations, with a motion variance estimated along
the track in a sliding window (so that, e.g., resting and travelling
contribute differently). dBGB further splits the motion variance into
components parallel and orthogonal to the direction of movement. They
are wrappers around
[`move2utils::mt_dbbmm_variance()`](https://move2universe.github.io/move2utils/reference/mt_dbbmm_variance.html)
and
[`move2utils::mt_dbbmm_ud()`](https://move2universe.github.io/move2utils/reference/mt_dbbmm_ud.html)
(or
[`move2utils::mt_dbgb_variance()`](https://move2universe.github.io/move2utils/reference/mt_dbgb_variance.html)
and
[`move2utils::mt_dbgb_ud()`](https://move2universe.github.io/move2utils/reference/mt_dbgb_ud.html)),
which require the suggested package `move2utils` (install it with
`remotes::install_github("move2universe/move2utils")`).

## Usage

``` r
hr_tt_dbbmm(
  x,
  location_error = NULL,
  window_size = 31,
  margin = 11,
  bbox = NULL,
  res = NULL,
  time_step = NULL,
  levels = NULL,
  ...
)

hr_tt_dbgb(
  x,
  location_error = NULL,
  window_size = 31,
  margin = 15,
  bbox = NULL,
  res = NULL,
  time_step = NULL,
  levels = NULL,
  ...
)
```

## Arguments

- x:

  A `move2` object with a projected coordinate reference system in
  metres, either ungrouped or grouped by its track id column.

- location_error:

  The error of the locations (the standard deviation of the position).
  Either a `units` object (e.g. `as_units(20, "m")`) with one value for
  all events or one value per event, the name of a column of `x` with
  the errors (as a `units` object), or `NULL` (the default) to treat
  locations as exact. Missing values are replaced by the median error of
  their track, as in `move2utils`.

- window_size:

  The number of events in the sliding window used to estimate the motion
  variance (an odd number). It is a number of events rather than a
  duration: with an event every 2 minutes, a window of 15 events covers
  30 minutes.

- margin:

  The number of events at each end of the window that are not considered
  as breakpoints when looking for changes in the motion variance (an odd
  number).

- bbox:

  A named vector of four elements (`xmin`, `ymin`, `xmax`, `ymax`), in
  the coordinates of `x`, defining the grid shared by all tracks. If
  `NULL`, the grid covers all the bridges (see Details).

- res:

  The resolution of the grid, as a `units` object (e.g.
  `as_units(50, "m")`). If `NULL`, it is chosen from the width of the
  bridges (see Details).

- time_step:

  The time step used to integrate the bridges, as a `units` object (e.g.
  `as_units(10, "s")`). If `NULL`, the default of `move2utils` is used
  (a fraction of the shortest interval between events).

- levels:

  A vector of levels for the isopleths, as numbers between 0 and 1. If
  `NULL` (the default), the full UDs are returned.

- ...:

  Further arguments passed to
  [`move2utils::mt_dbbmm_variance()`](https://move2universe.github.io/move2utils/reference/mt_dbbmm_variance.html)
  or
  [`move2utils::mt_dbgb_variance()`](https://move2universe.github.io/move2utils/reference/mt_dbgb_variance.html)
  (e.g. `parallel` and `cores`).

## Value

Either a `tibble` of class `hr_tt_ud_tbl`, or, if `levels` is not
`NULL`, an `sf` tibble of class `hr_tt_poly_tbl` (as returned by
[`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md)),
with columns:

- the track id column of `x`: the ids of the tracks, in the order of the
  metadata (see
  [`show_meta()`](https://evolecolgroup.github.io/tidytracks/dev/reference/show_meta.md))
  if `x` is not grouped, or else in the order of
  [`dplyr::group_keys()`](https://dplyr.tidyverse.org/reference/group_data.html)
  (i.e. sorted by track id)

- `method`: the method used to estimate the home range (`"dbbmm"` or
  `"dbgb"`)

- `window_size` and `margin`: the values used for the sliding window

- `xmin`, `ymin`, `xmax`, `ymax` and `res`: the extent and resolution of
  the grid (in metres)

- `ud` (if `levels` is `NULL`): the UDs, as a list of
  [`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
  objects with a layer named `ud` whose values sum to 1

- `level`, `area` and `geometry` (if `levels` is set): the isopleths,
  see
  [`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md)

## Details

Bridges link consecutive events within a track, so the UD is estimated
for each track: `x` must be either ungrouped, or grouped by its track id
column only. `x` must be ordered by time within each track (see
[`tt_order_time()`](https://evolecolgroup.github.io/tidytracks/dev/reference/tt_order_time.md)),
and have a projected coordinate reference system in metres (see
[`sf::st_transform()`](https://r-spatial.github.io/sf/reference/st_transform.html)),
as the bridges are computed in metres. Events with an empty geometry
(i.e. no location) are ignored. Tracks with fewer events than
`window_size` are skipped by `move2utils` (with a warning), and are not
included in the output.

**The grid.** The UDs of all tracks are estimated on a shared grid,
which must contain the whole of every bridge: bridges can extend well
beyond the locations (e.g. across long gaps between events, when the
motion variance is high). The motion variance is therefore estimated
first, and used to compute the extent of each bridge (up to five
standard deviations from its mean path). If `bbox` is `NULL` (the
default), the grid covers the extent of all the bridges, plus five cells
on each side. If `bbox` is given and does not contain all the bridges
(with a margin of two cells), an error is given, reporting the extent
needed.

The grid must also be fine relative to the width of the bridges, as the
densities are evaluated at the centres of the cells: bridges much
narrower than the cells (e.g. with frequent, accurate locations) can
fall between them, giving a patchy UD (or an error, if no density is
left). If `res` is `NULL` (the default), the cells are as wide as the
median width of the bridges (their standard deviation half way between
consecutive events), but no smaller than needed for the longest side of
the grid (the extent of the bridges, or `bbox` if given) to have 500
cells. A warning is given if the cells are more than ten times wider
than the median width of the bridges.

Note that these defaults differ from the grid used by
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
(the extent of the locations, expanded by 100% of the range on each
side, with about 1000 cells). To compare the UDs from different methods
(e.g. with
[`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)),
estimate them on the same grid, e.g. by passing the grid of the bridges
(columns `xmin`, `ymin`, `xmax`, `ymax` and `res` of the output) as
`bbox` and `res` to
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md).

If `levels` is set, the isopleths for the specified levels are returned
instead of the full UDs, as in
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md).

## References

Kranstauber, B., Kays, R., LaPoint, S. D., Wikelski, M. & Safi, K.
(2012). A dynamic Brownian bridge movement model to estimate utilization
distributions for heterogeneous animal movement. *Journal of Animal
Ecology*, 81, 738-746.
[doi:10.1111/j.1365-2656.2012.01955.x](https://doi.org/10.1111/j.1365-2656.2012.01955.x)

Kranstauber, B., Safi, K. & Bartumeus, F. (2014). Bivariate Gaussian
bridges: directional factorization of diffusion in Brownian bridge
models. *Movement Ecology*, 2, 5.
[doi:10.1186/2051-3933-2-5](https://doi.org/10.1186/2051-3933-2-5)

## Examples

``` r
# project the data to a projection in metres
x <- sf::st_transform(example_tt, "+proj=eqearth")
ud_dbbmm <- hr_tt_dbbmm(
  x,
  location_error = as_units(1000, "m"),
  window_size = 3,
  margin = 1
)
ud_dbbmm
#> # A tibble: 3 × 10
#>   track_id method window_size margin      xmin      ymin     xmax    ymax    res
#>   <chr>    <chr>        <dbl>  <dbl>     <dbl>     <dbl>    <dbl>   <dbl>  <dbl>
#> 1 a        dbbmm            3      1 -1546354. -1361159. 1626768.  1.81e6 99160.
#> 2 b        dbbmm            3      1 -1546354. -1361159. 1626768.  1.81e6 99160.
#> 3 c        dbbmm            3      1 -1546354. -1361159. 1626768.  1.81e6 99160.
#> # ℹ 1 more variable: ud <named list>
# estimate kernel UDs on the same grid, to compare them
ud_kde <- hr_tt_kde(
  x,
  bbox = unlist(ud_dbbmm[1, c("xmin", "ymin", "xmax", "ymax")]),
  res = ud_dbbmm$res[1]
)
hr_tt_ud_overlap(ud_dbbmm$ud[[1]], ud_kde$ud[[1]])
#> [1] 0.7838233
```
