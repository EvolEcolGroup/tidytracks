# Return a trajectory line for each track

Converts each track into one line. This function returns a
[`sf::sf`](https://r-spatial.github.io/sf/reference/sf.html) object with
a `LINESTRING` representing the trajectory as geometry for each track,
as well as additional columns of information from the metadata table.

## Usage

``` r
track_lines(x, ...)
```

## Arguments

- x:

  A move object

- ...:

  Arguments passed on to the
  [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
  function

## Value

A [sf::sf](https://r-spatial.github.io/sf/reference/sf.html) object with
a `LINESTRING` representing the track as geometry for each track. The
metadata for each track is included as well as the products from
summarize

## Details

Note that all empty points are removed before summarizing. Arguments
passed with `...` thus only summarize for the non empty locations.
