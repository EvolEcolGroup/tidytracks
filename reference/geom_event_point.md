# A `ggplot2` geometry to plot events as points

This function provides a `ggplot2` geometry to plot events as points. It
is a wrapper around `[ggplot2::geom_sf()]`, thus allowing for
projections to be set using the
[`ggplot2::coord_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)\`
function. See
[`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
for details

## Usage

``` r
geom_event_point(
  mapping = ggplot2::aes(),
  data = NULL,
  stat = "sf",
  position = "identity",
  na.rm = FALSE,
  show.legend = NA,
  ...
)
```

## Arguments

- mapping:

  Set of aesthetic mappings created by
  [`ggplot2::aes()`](https://ggplot2.tidyverse.org/reference/aes.html).
  Variables from the events table can be used for mapping. If none is
  provided a basic aesthetics for the `sf` points will be used, as it is
  the case for
  [`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html).

- data:

  A `move2` object, with the columns from the events table available for
  mapping.

- stat:

  The statistical transformation to use on the data for this layer. The
  default is "sf", which should normally be left unchanged.

- position:

  The position adjustment to use for overlapping points on this layer.
  The default is "identity", meaning no adjustment will be made to the
  data.

- na.rm:

  If FALSE, the default, missing values are removed with a warning. If
  TRUE, missing values are silently removed.

- show.legend:

  logical. Should this layer be included in the legends? The default is
  NA, which includes if any aesthetics are mapped. It can also be a
  named logical vector to finely select the aesthetics to display.

- ...:

  Other arguments passed on to
  [`ggplot2::layer()`](https://ggplot2.tidyverse.org/reference/layer.html).

## Value

A `ggplot2` layer object.

## Examples

``` r
library(ggplot2)
ggplot() +
  geom_event_point(data = example_tt, mapping = aes(color = track_id))
```
