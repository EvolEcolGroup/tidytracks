# Autoplot a tibble of utilisation distributions

This autoplot function can be used to plot all or a subset of UDs from a
tibble of UDs created by
[`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md).
The UDs are identified by the columns before `method` (the grouping
variables used to estimate them), or else by the first column of the
tibble. The layout of the plots can be specified with the `layout`
argument, and it is assembled with `patchwork`.

## Usage

``` r
# S3 method for class 'hr_tt_ud_tbl'
autoplot(object, id_to_plot = NULL, layout = NULL, ...)
```

## Arguments

- object:

  A tibble of utilisation distributions created by kde of class
  `hr_tt_ud_tbl` as created with
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md).

- id_to_plot:

  Integer or character, the position or id of the utilisation
  distributions to plot. If `NULL`, all utilisation distributions in the
  tibble are plotted. The ids are the values of the columns that
  identify the UDs (separated by "\_" if there are several, with
  locations written as WKT, as in
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)).

- layout:

  A vector of length 2, the number of rows and columns in the plot
  layout. If `NULL`, the layout is determined automatically.

- ...:

  Not used.

## Value

A patchwork plot object created with
[`patchwork::wrap_plots()`](https://patchwork.data-imaginist.com/reference/wrap_plots.html).
When one utilisation distribution is selected, the result is a
single-panel plot composition; when multiple utilisation distributions
are selected, the result is a multi-panel plot composition.

## Examples

``` r
example_kde <- hr_tt_kde(example_tt)
library(ggplot2)
autoplot(example_kde)
```
