# Quantify the home range using minimum convex polygon (MCP)

This function estimates the home range of an animal using the minimum
convex polygon (MCP) method.

## Usage

``` r
hr_mcp(x, levels = c(0.5, 0.95))
```

## Arguments

- x:

  A grouped move2 object

- levels:

  A vector of levels for the contour lines. The default is
  `c(0.5, 0.95)`, which corresponds to the 50% and 95% home ranges.

## Value

A tibble of subclass `hr_poly_tbl` of results, with columns:

- `group_id`: the ids from the grouping of `x`

- `level`: the level of the contour line

- `geometry`: the geometry of the home range as a list of sf polygons
