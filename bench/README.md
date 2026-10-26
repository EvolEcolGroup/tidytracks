# Benchmark: `hr_tt_locoh()` vs `amt::hr_locoh()`

`locoh_benchmark.R` compares the Rcpp implementation of LoCoH in tidytracks
(`hr_tt_locoh()`) with `amt::hr_locoh()`, for the three types of LoCoH
(`"k"`, `"r"` and `"a"`), on one real track (the wild boar Brock, 30
locations) and on simulated tracks of 500 to 5000 locations. Run it from the
root of the package with:

```sh
Rscript bench/locoh_benchmark.R
```

amt buffers every hull by 1e-5 (its `rand_buffer`), so `hr_tt_locoh()` is
timed with `buffer = 1e-5` (`tidytracks_buffer_ms`, used for the speed-up and
for checking the results) and with its default, `buffer = 0`
(`tidytracks_ms`). Both are given the same data, already converted to their
respective classes; the levels are 0.5 and 0.95. For `"r"` and `"a"`, `n` is
the median distance to the 10th nearest neighbour, and 10 times that.

## Results

Median times in ms, from `bench::mark()`, on a 4-core Linux container (R 4.3.3,
amt 0.3.1.0, sf 1.1-3 with GEOS 3.12.1). `max_rel_area_diff` is the largest
relative difference between the areas of the home ranges from the two
packages.

| data       | locations | type |       n | amt_ms | tidytracks_buffer_ms | tidytracks_ms | speed-up | max_rel_area_diff |
|------------|----------:|------|--------:|-------:|---------------------:|--------------:|---------:|------------------:|
| boar_brock |        30 | k    |   10.00 |   34.7 |                 33.2 |          31.6 |      1.0 |           7.3e-09 |
| boar_brock |        30 | r    |  309.40 |   33.1 |                 31.3 |          32.8 |      1.1 |           9.4e-09 |
| boar_brock |        30 | a    | 3094.00 |   27.6 |                 40.2 |          34.5 |      0.7 |           2.0e-12 |
| sim_500    |       500 | k    |   10.00 |  321.4 |                 50.1 |          47.7 |      6.4 |           2.0e-09 |
| sim_500    |       500 | r    |  109.50 |  330.5 |                 64.5 |          42.3 |      5.1 |           1.7e-08 |
| sim_500    |       500 | a    | 1095.00 |  328.9 |                 48.0 |          47.7 |      6.8 |           1.8e-09 |
| sim_1000   |      1000 | k    |   10.00 |  579.1 |                 71.5 |          67.5 |      8.1 |           2.5e-09 |
| sim_1000   |      1000 | r    |  118.20 |  596.8 |                 99.1 |          67.1 |      6.0 |           1.5e-08 |
| sim_1000   |      1000 | a    | 1182.00 |  768.6 |                 73.1 |          66.5 |     10.5 |           7.9e-10 |
| sim_2000   |      2000 | k    |   10.00 | 1245.4 |                119.5 |         111.2 |     10.4 |           5.7e-09 |
| sim_2000   |      2000 | r    |   82.98 | 1217.8 |                155.8 |         100.3 |      7.8 |           2.1e-08 |
| sim_2000   |      2000 | a    |  829.80 | 1784.6 |                116.6 |         107.3 |     15.3 |           2.1e-09 |
| sim_5000   |      5000 | k    |   10.00 | 3053.4 |                306.2 |         296.6 |     10.0 |           5.4e-09 |
| sim_5000   |      5000 | r    |   55.26 | 3479.8 |                436.6 |         227.6 |      8.0 |           2.4e-08 |
| sim_5000   |      5000 | a    |  552.60 | 5921.7 |                290.7 |         234.2 |     20.4 |           2.5e-09 |

- From 500 locations up, `hr_tt_locoh()` is 5 to 20 times faster than
  `amt::hr_locoh()`, and the gap grows with the number of locations (and is
  largest for `"a"`, for which amt sorts the distances from each location to
  all the others).
- On a very small track (30 locations), both take about 30 ms: at that size,
  fixed overheads dominate rather than the LoCoH computations themselves.
- The home ranges are the same: the areas differ by at most 2.4e-8 (relative),
  which is floating point noise from buffering the union of the hulls rather
  than each hull.

## Where does the time go?

For the 5000 simulated locations with `type = "k"`, the C++ code (neighbour
search, hulls, sorting, coverage of the levels) takes 13.6 ms of the 229 ms
of the whole function. Almost all the rest is the union of the ~3000 hulls of
the 95% isopleth, computed by GEOS through `sf::st_union()`.

By contrast, amt (in R) builds one data frame per hull, buffers each hull
(which multiplies the number of vertices that the union then has to process),
and, for `"r"` and `"a"`, computes the distances from each location to all the
others, which grows with the square of the number of locations.
