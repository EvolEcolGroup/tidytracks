# Create mcp at multiple levels for a given group

This is the internal function that is called by `hr_mcp` to create the
MCP at multiple levels for a given group. It is not intended to be
called directly by the user.

## Usage

``` r
mcp_one_group(xy, levels, crs)
```

## Arguments

- xy:

  a matrix of coordinates

- levels:

  A vector of levels for the contour lines

- crs:

  the crs of the coordinates (to use in the geometry)

## Value

A list of sf polygons representing the MCP at each level
