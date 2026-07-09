# A `ggplot2` geometry to plot event steps as paths

This function provides a `ggplot2` geometry to plot steps between events
as paths. It uses
[`move2::mt_segments()`](https://bartk.gitlab.io/move2/reference/mt_segments.html)
to create `sf` lines joining each consecutive pair of events (i.e.
steps. These steps are then added to the events table (with a point for
the last event of each track), so that all variables in the event table
are available for mapping the aesthetics. The resulting `sf` lines are
then plotted via a wrapper around `[ggplot2::geom_sf()]`, thus allowing
for projections to be set using the
[`ggplot2::coord_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)\`
function. See
[`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html)
for details.

## Usage

``` r
geom_event_path(
  mapping = ggplot2::aes(),
  data = NULL,
  drop_final_point = TRUE,
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
  Variables from the *events* table can be used for mapping. If none is
  provided a basic aesthetics for the `sf` step segments (i.e. lines)
  will be used, as it is the case for
  [`ggplot2::geom_sf()`](https://ggplot2.tidyverse.org/reference/ggsf.html).

- data:

  The `move2` object to be displayed. For this geometry, there is no
  inheritance from the main `ggplot()` call, and data has to be
  specified.

- drop_final_point:

  Logical, default is `TRUE`. The
  [`move2::mt_segments`](https://bartk.gitlab.io/move2/reference/mt_segments.html)
  function cannot create a segment for the final point in each track, so
  it is left as a `POINT` geometry. If `TRUE`, we filter to `LINESTRING`
  geometries only (this is necessary for the animation function to
  work).

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

## Details

Units (implemented via the package `units`) are produced by many
operations, but are not fully compatible with `ggplot2`. This function
internally drops units before creating a `ggplot2` layer.
