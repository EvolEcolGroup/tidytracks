# Bug report for move2utils: out-of-bounds write in the Brownian bridge kernels

Draft report for the `move2utils` maintainers. The development repository of
`move2utils` is on MPCDF GitLab, mirrored at
<https://github.com/move2universe/move2utils>. The files in this folder are:

- `README.md`: the report (below), ready to be pasted into an issue.
- `reproduce_window.R`: deterministic reproduction.
- `stress_crash.R`: stress test that crashes R.
- `fix-bridge-grid-bounds.patch`: the proposed fix (applies cleanly to
  `move2utils` 0.4.5, commit `3c2c4a2`).

---

## `mt_dbbmm_ud()` / `mt_dbgb_ud()` write out of bounds when a bridge reaches the edge of the grid

### Summary

The grid bounds checks in the C kernels that compute dBBMM and dBGB
utilisation distributions are off by one. When the integration window of a
bridge ends exactly one cell beyond the last column (or row) of the grid, the
check passes, and the kernel writes past the end of the output matrix. No
error is given: the function returns a UD, but R's heap is corrupted, which
can crash R later (`*** caught segfault ***`, `malloc(): invalid next size`)
or silently corrupt other objects.

This happens whenever a grid is only just large enough for the bridges, e.g.
a grid supplied with `raster = <SpatRaster>`, or an automatic grid with a
small `ext`.

### Affected code

`src/bgb_bbmm_omp.c`, in `dbbmm2_omp()` (called by
`mt_dbbmm_ud.mt_dbbmm_variance()`) and `bgb_omp()` (called by
`mt_dbgb_ud.mt_dbgb_variance()`). The legacy `dbbmm2()` and `bgb()` in
`src/bgb_bbmm.c`, which are still registered in `src/init.c`, have the same
problem.

For each time step, the kernel computes the window of cells to integrate over,
checks it against the size of the grid, and loops over it **inclusively**:

```c
int xEnd   = (int)ceil((mux - x0) / xRes + sigma_ext / xRes);
int yEnd   = (int)nYGrid - floor((muy - y0) / yRes - sigma_ext / yRes);
...
if (xEnd > nXGrid)      /* allows xEnd == nXGrid */
    error("Higher x grid not large enough, ...");
if (yEnd > nYGrid)      /* allows yEnd == nYGrid */
    error("Lower y grid not large enough, ...");
...
for (int ii = xStart; ii <= xEnd; ii++) {
    for (int jj = yStart; jj <= yEnd; jj++) {
        double dx = xxGrid[ii] - mux;
        double dy = xyGrid[nYGrid - jj - 1] - muy;
        ...
        rans[ii * nYGrid + jj] += ...;
    }
}
```

The valid indices are `0 .. nXGrid - 1` and `0 .. nYGrid - 1`, so:

- with `xEnd == nXGrid`, the loop reads `xxGrid[nXGrid]` and writes
  `rans[nXGrid * nYGrid + jj]`, i.e. past the end of the
  `nYGrid` x `nXGrid` matrix;
- with `yEnd == nYGrid`, it reads `xyGrid[-1]` and writes
  `rans[ii * nYGrid + nYGrid]`, which is the first cell of the next column
  (a wrong cell), or past the end of the matrix for the last column.

### Reproduction

`reproduce_window.R` replicates, in R, the window that `dbbmm2_omp()` computes
for each time step, and builds a grid with exactly as many columns as the
largest `xEnd`. `mt_dbbmm_ud()` accepts this grid although 29 time steps have
a window ending at column index `ncol` (one past the last column). As a check
that the replicated windows match the C code, a grid with one column fewer
does give the "grid not large enough" error:

```
columns in grid: 69
largest x_end of a window: 69
time steps whose window reaches column index ncol: 29
mt_dbbmm_ud() returned without error, although the loop wrote past the end of the output matrix
with 68 columns: Higher x grid not large enough, consider extending the raster in that direction or enlarging the ext argument
```

`stress_crash.R` alternates grids that are just too small with grids that are
large enough, as happens when a user searches for a suitable grid. With
`move2utils` 0.4.5, it crashed R in two of three runs:

```
 *** caught segfault ***
```

As heap corruption is only detected later, the crash happens in unrelated
code (in our runs, during memory allocation in `.split_tracks()` or `gc()`),
and not on every run.

### Suggested fix

Make the upper bounds checks strict, in all four kernels
(`fix-bridge-grid-bounds.patch`):

```diff
-        if (xEnd > nXGrid)
+        if (xEnd >= nXGrid)
             error("Higher x grid not large enough, ...");
-        if (yEnd > nYGrid)
+        if (yEnd >= nYGrid)
             error("Lower y grid not large enough, ...");
```

(and the same in `bgb_omp()`, `dbbmm2()` and `bgb()`). An alternative would be
to clamp the windows to the grid, but that would silently drop probability
mass; an error is consistent with the current behaviour for grids that are too
small.

### Verification

With the patch applied to `move2utils` 0.4.5:

- `reproduce_window.R`: the 69-column grid gives "Higher x grid not large
  enough", as expected.
- `stress_crash.R`: three runs out of three finish without crashing.
- Shrinking grids cell by cell from each side, for both `mt_dbbmm_ud()` and
  `mt_dbgb_ud()` on four datasets, every call either succeeded or gave the
  "grid not large enough" error, with no crashes.
- UDs on grids that are large enough are unchanged, as the patch only affects
  windows that reach the edge of the grid.

### Environment

R 4.5.3 on Linux (6.18), `move2utils` 0.4.5 (commit `3c2c4a2`), `move2`
0.5.0, `terra` 1.9.50, `sf` 1.1.3.

### Context

Found while wrapping `mt_dbbmm_ud()` and `mt_dbgb_ud()` in `tidytracks`
(<https://github.com/EvolEcolGroup/tidytracks>). Until a fix is released,
`tidytracks::hr_tt_dbbmm()` and `hr_tt_dbgb()` estimate the motion variance
first, compute a conservative extent for every bridge, and only call the
kernel on grids that contain all bridges with a margin of two cells.
