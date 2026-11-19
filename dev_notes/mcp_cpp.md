# MCP in C++ (parked)

A design for computing the minimum convex polygons of `hr_tt_mcp()`
(`R/hr_tt_mcp.R`) in C++. It is meant for many short tracks, where nearly all
of the time is R overhead per group. It was studied during the attribution
audit (November 2026, `code_review_attribution_2026-11.md`) and parked by
Andrea on 19 Nov 2026: MCP is already 10x faster than amt and adehabitatHR in
the home range benchmark, and the C++ hull cannot reproduce
`grDevices::chull()` in every degenerate case.

## Design decisions

| decision | alternatives considered | why | date | decided by |
|---|---|---|---|---|
| Park the C++ MCP | do it now | MCP is not a bottleneck, and the results would differ from `chull()` for nearly collinear sets (below) | 2026-11-19 | Andrea |
| For now, keep `grDevices::chull()` in R, with an inline type 7 quantile and the polygons built directly | C++ | identical results, 15% faster (`d2d0a80`) | 2026-11-18 | Claude, agreed |

## Where the time goes now

These are per group (one track of 500 locations, 2 levels), on manica01, one
P-core, at `d2d0a80`. `mcp_one_group()` takes about 170-200 µs:

| step | µs |
|---|---|
| `grDevices::chull()` | 45 per level; its C algorithm takes 4.4 of these, the rest is the R wrapper (`xy.coords()` 16, the angle sort 23) |
| centroid and squared distances | 10 |
| type 7 quantile (partial sort) | about 11 |
| subsetting the locations of each level | 5 per level |
| building the polygon (`structure()`) | 2.5 per level |
| `foreach` per iteration | about 40 |

For 10,000 tracks of 500 locations, `hr_tt_mcp()` takes 3.6 s; about 2 s of
it is this per-group work. The rest (grouping, `st_coordinates()`, the areas)
is shared with the other `hr_tt_*()` functions.

## How it would work

- **One C++ function over all the groups:** the coordinates, the group of
  each location, and the levels. For each group and level it returns the ring
  of the MCP (or an empty polygon), as `sfg` objects built in C++, as
  `hull_to_sfg()` does in `src/locoh.cpp`.
- **Per group:**
  1. the centroid as `colMeans()` computes it: the sum in `long double`,
     divided by n in `long double`, then cast to double;
  2. the squared distances `dx * dx + dy * dy`, with fp-contract off (as in
     `src/locoh.cpp`);
  3. the type 7 quantile of each level, from the two order statistics found
     with `std::nth_element`, using R's expression
     `(1 - h) * x[lo] + h * x[hi]`, only where `index > lo` and the two
     differ;
  4. the locations at or within the threshold, kept in their original order;
  5. their hull, with `monotone_chain()` of `src/locoh.cpp`, after dropping
     exact duplicates;
  6. the vertices ordered as `chull()` orders them: by
     `atan2(y - my, -(x - mx))`, around the centroid of the vertices
     (computed as `colMeans()` does), increasing, with ties in input order;
     then closing the ring.
- **Expected gain:** about 10x on the per-group work (the hull is 4 µs in C
  for 500 points), so 10,000 tracks of 500 locations in about 1.5 s
  instead of 3.6 s.

## Why the results would differ (the catch)

`chull()` uses Eddy's algorithm, which tests each point against the line
through two vertices in slope-intercept form, in floating point. The
monotone chain uses the cross product. For nearly collinear points (and
duplicates), the two can choose different vertex sets:

- 2,535 hulls of real and simulated tracks (the benchmark tracks, shags,
  buffalo, wild boar; levels 0.05 to 1): **no** difference in the vertex
  sets;
- 20,000 deliberately degenerate sets (grids, duplicates, rounded
  coordinates, points on a line within 1e-15): **607** differences (3%).

The polygons would then differ by vertices within rounding of an edge, with
the same area up to rounding. A C++ version would therefore have to be
accepted as "the same up to degenerate cases", or replace `chull()` with the
exact hull (`TurnExact` in `src/locoh.cpp`), which is arguably more correct.

## Numbers

| measure | value | machine | commit | date |
|---|---|---|---|---|
| `hr_tt_mcp()`, 10,000 tracks of 500 locations | 4.23 s (`dev`) and 3.59 s (R rewrite) | manica01, P-core | `6b3d855`, `d2d0a80` | 2026-11-18 |
| `hr_tt_mcp()`, 100 tracks of 10,000 locations | 0.247 s and 0.226 s | manica01, P-core | `6b3d855`, `d2d0a80` | 2026-11-18 |
| `grDevices::chull()`, 500 points: total and C part | 45 µs and 4.4 µs | manica01, P-core | — | 2026-11-18 |
| vertex sets of `chull()` vs the monotone chain | 0 differences in 2,535 real hulls; 607 in 20,000 degenerate sets | manica01 | `1d2cd34` | 2026-11-18 |

To reproduce: time `hr_tt_mcp()` on 100 copies of the medium tracks of
`vignettes/articles/data/hr_benchmark_tracks.rds` (see
`vignettes/articles/code/hr_benchmark.R` for how the copies are made), with
release builds in separate libraries (the `benchmarking` skill).

## Open questions

- Is MCP on many tracks ever a bottleneck for users? If it is, do it.
- If it is done, should it use the exact hull (a change in degenerate cases
  only, documented in NEWS), or try to mimic Eddy's tests?
