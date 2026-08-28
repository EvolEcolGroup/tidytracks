# Save utilisation distributions as an RDS file

Wraps an `hr_ud_tbl` before saving it with
[`base::saveRDS()`](https://rdrr.io/r/base/readRDS.html). This avoids
writing live
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html)
objects to disk. The object returned by
[`base::readRDS()`](https://rdrr.io/r/base/readRDS.html) has a wrapped
`ud` column. Functions that operate on an `hr_ud_tbl` unwrap this column
automatically; use
[`hr_ud_unwrap()`](https://evolecolgroup.github.io/tidytracks/reference/hr_ud_unwrap.md)
to restore it explicitly for repeated analyses.

## Usage

``` r
hr_ud_saveRDS(x, file, compress = TRUE, version = NULL, ...)
```

## Arguments

- x:

  An `hr_ud_tbl` with a `ud` list-column.

- file:

  A connection or character string naming the RDS file.

- compress:

  A logical or character value passed to
  [`base::saveRDS()`](https://rdrr.io/r/base/readRDS.html).

- version:

  The RDS serialization format version passed to
  [`base::saveRDS()`](https://rdrr.io/r/base/readRDS.html).

- ...:

  Additional arguments passed to
  [`base::saveRDS()`](https://rdrr.io/r/base/readRDS.html).

## Value

`NULL`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
example_kde <- hr_kde(example_tt)
hr_ud_saveRDS(example_kde, "example-kde.rds")
loaded_kde <- readRDS("example-kde.rds")
} # }
```
