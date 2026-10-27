# Deprecated functions in tidytracks

These functions have been renamed with an `hr_tt_` prefix to avoid name
clashes with other packages. The old names still work for backwards
compatibility, but they issue a warning and will be removed in a future
release. Please use the new names instead.

## Usage

``` r
hr_kde(
  x,
  h = "h_ref_mean",
  bbox = NULL,
  res = NULL,
  levels = NULL,
  method = c("binned", "exact")
)

hr_mcp(x, levels = c(0.5, 0.95))

hr_ud_iso(x, levels = c(0.5, 0.95))

hr_ud_overlap(...)

hr_ud_wrap(x)

hr_ud_unwrap(x)

hr_ud_saveRDS(...)

hr_ud_sum(x)
```

## Arguments

- x, h, bbox, res, levels, method, ...:

  Arguments passed to the replacement function; see its documentation
  for details.

## Value

The output of the replacement function.

## Details

The deprecated functions and their replacements are:

- `hr_kde()`: use
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)

- `hr_mcp()`: use
  [`hr_tt_mcp()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_mcp.md)

- `hr_ud_iso()`: use
  [`hr_tt_ud_iso()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_iso.md)

- `hr_ud_overlap()`: use
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)

- `hr_ud_sum()`: use
  [`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)

- `hr_ud_wrap()`: use
  [`hr_tt_ud_wrap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_wrap.md)

- `hr_ud_unwrap()`: use
  [`hr_tt_ud_unwrap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_unwrap.md)

- `hr_ud_saveRDS()`: use
  [`hr_tt_ud_saveRDS()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_saveRDS.md)
