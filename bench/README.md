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
the 95% isopleth, computed by GEOS through `sf::st_union()` (see the profile
below for details).

By contrast, amt (in R) builds one data frame per hull, buffers each hull
(which multiplies the number of vertices that the union then has to process),
and, for `"r"` and `"a"`, computes the distances from each location to all the
others, which grows with the square of the number of locations.

# Profile, and can we go faster (e.g. with OpenMP)?

Two scripts profile `hr_tt_locoh()`:

- `locoh_profile.R` times each stage of the function, for single tracks of
  1000 to 50,000 locations, and the whole function for many short tracks;
- `locoh_profile_cpp.R` (with `locoh_profile_cpp.cpp`) times each phase of
  the C++ code, and a prototype that runs the neighbour search and the hulls
  in parallel with OpenMP.

Run them from the root of the package (with tidytracks installed with
`R CMD INSTALL`: `devtools::load_all()` compiles the C++ code without
optimisation, which makes it 4 to 6 times slower). Timings below are medians,
in ms, on 4 cores.

## Single tracks: the union of the hulls dominates

| locations | type | whole | C++ | `st_sfc()` | union (GEOS) | after the union | C++ share | union share |
|----------:|------|------:|----:|-----------:|-------------:|----------------:|----------:|------------:|
|      1000 | k    |    60 |   3 |          1 |           33 |              10 |        5% |         54% |
|      5000 | k    |   249 |  14 |          4 |          194 |              10 |        6% |         78% |
|      5000 | a    |   287 |  28 |          3 |          173 |              11 |       10% |         60% |
|     20000 | k    |  1001 |  66 |         14 |          923 |              15 |        7% |         92% |
|     50000 | k    |  2571 | 243 |         53 |         2186 |              16 |        9% |         85% |
|     50000 | r    |  2843 | 123 |         23 |         2368 |              28 |        4% |         83% |
|     50000 | a    |  2392 | 286 |         32 |         2020 |              15 |       12% |         84% |

The union of the hulls, computed by GEOS (single-threaded), takes 40% to 92%
of the time (over 75% from 5000 locations on, for all types), and its share
grows with the number of locations. All the C++ code takes 3% to 16%.

Within the C++ code, the neighbour search is the largest phase, followed by
the hulls and by turning the hulls into R objects (which must be done by a
single thread, as R's API is not thread-safe):

| locations | type | tree | neighbours (incl. tree) | hulls | sort, levels | R objects |
|----------:|------|-----:|------------------------:|------:|-------------:|----------:|
|      5000 | k    |  0.6 |                     7.1 |   2.6 |          0.5 |       3.1 |
|      5000 | a    |  0.6 |                    17.9 |   3.5 |          0.5 |       2.8 |
|     50000 | k    |  7.8 |                    79.4 |  28.9 |          6.5 |      43.9 |
|     50000 | a    |  7.8 |                   216.8 |  38.6 |          7.5 |      52.8 |
|    200000 | k    | 38.9 |                   407.2 | 135.3 |         32.4 |     400.0 |

## OpenMP: it works, but would barely change the total

The neighbour search and the hulls are independent for each location, so they
parallelise well. The prototype in `locoh_profile_cpp.cpp` runs them 2.6 to 3
times faster on 4 threads:

| locations | 1 thread | 2 threads | 4 threads |
|----------:|---------:|----------:|----------:|
|      5000 |      9.8 |       5.2 |       3.3 |
|     50000 |    127.1 |      69.6 |      38.5 |
|    200000 |    593.2 |     340.1 |     206.9 |

But these phases are only 3% to 11% of the whole function, so (Amdahl's law)
OpenMP would make `hr_tt_locoh()` only 2% to 7% faster: e.g. about 6 ms out of
250 ms for 5000 locations, or about 90 ms out of 2.6 s for 50,000. For that,
it would add a build dependency that is awkward on macOS (Apple's compiler has
no OpenMP, so the code must also build without it), a thread setting that
must default to at most 2 threads on CRAN, and restructuring of the neighbour
search (which fills a shared array in order and checks for user interrupts
from R). It is not worth it at present.

## The union: alternatives tested

The union of the ~4400 (5000 locations) and ~46,000 (50,000 locations) hulls
of the 95% isopleth, type `"k"`:

| approach                                           | 5000 locations | 50,000 locations | same result?          |
|----------------------------------------------------|---------------:|-----------------:|-----------------------|
| GEOS cascaded union (current)                      |            163 |             1683 | -                     |
| Clipper (`polyclip`), all hulls in one pass        |            140 |             4210 | yes (3e-9)            |
| drop hulls covered by another hull, then GEOS      |      131 + 151 |      1349 + 1607 | yes                   |
| GEOS on 4 vertical strips in 4 processes, merged   |            105 |              929 | yes                   |

- Clipper scales worse than GEOS with the number of hulls.
- Only about 9% of the hulls are covered by another single hull, and finding
  them costs as much as the union.
- Computing the union of each level from scratch, rather than adding hulls
  to the union of the previous level, is no faster (within 10% either way,
  depending on the type).
- Splitting the union between processes gains 1.6 to 1.8 times, but forking
  processes is not available on Windows, and a package should not start
  processes on its own; users with many groups can instead run groups in
  parallel themselves (e.g. with `parallel::mclapply()` or `future`).

## Many short tracks: fixed costs (fixed)

With one track per foraging trip, data sets often have hundreds of short
tracks. Profiling 500 tracks of 50 locations showed that most of the time
went to fixed costs repeated for every track, not to the LoCoH: 52% to sf
asking PROJ for the parameters of the CRS (about 3 ms for
`sf::st_is_longlat()` and 9 ms for `sf::st_area()` of one polygon, both called
for every track), and 15% to combining the results of the tracks one at a
time (quadratic in the number of tracks). `hr_tt_locoh()` now looks up the
CRS once, computes all the areas in one call, and combines the tracks once,
with identical results:

| tracks | locations per track | before | after | speed-up |
|-------:|--------------------:|-------:|------:|---------:|
|     10 |                 500 |    409 |   272 |      1.5 |
|    100 |                  50 |   2126 |   618 |      3.4 |
|   1000 |                  50 |  22192 |  6118 |      3.6 |

(type `"k"`; up to 4.4 times for type `"r"`). The remaining ~6 ms per track is
mostly the union of its hulls, building `sfc` objects, and building a small
tibble per track; assembling the columns of all tracks and building one tibble
at the end could roughly halve it again.

`hr_tt_mcp()` had the same fixed costs (63% of its time went to
`sf::st_area()`, called for each track, and 21% to combining the tracks one at
a time), and has the same fix, also with identical results:

| tracks | locations per track | before | after | speed-up |
|-------:|--------------------:|-------:|------:|---------:|
|      1 |                5000 |     29 |    31 |      0.9 |
|     10 |                 500 |    163 |    58 |      2.8 |
|    100 |                  50 |   1520 |   336 |      4.5 |
|   1000 |                  50 |  16483 |  3311 |      5.0 |

# Can tracks be processed in parallel?

`hr_tt_mcp()`, `hr_tt_kde()` and `hr_tt_locoh()` compute the home range of
each track (or group) independently, one after the other, so the tracks could
be processed in parallel.

## None of them uses several threads within a track

Their CPU time is the same as their elapsed time (20,000 locations): they use
a single thread. The one exception is on systems where R uses a
multithreaded BLAS (OpenBLAS, MKL, or Accelerate on macOS; R's own reference
BLAS, the default on Windows and macOS, is single-threaded): `MASS::kde2d()`,
used by `hr_tt_kde()`, computes the densities with a matrix product, which
dominates on fine grids (88 s for 20,000 locations with `res = 10`, here) and
would then use several threads. When running tracks in parallel on such a
system, the BLAS should be limited to one thread per worker (e.g. with
`RhpcBLASctl::blas_set_num_threads(1)`), to avoid oversubscribing the cores.

## Prototype and timings

`parallel_prototype.patch` replaces `%do%` with doFuture's `%dofuture%` in
the loop over the tracks of the three functions, so that they follow the plan
set by the user with `future::plan()`. Each task only receives the coordinates
of its tracks, and full UDs (terra rasters, which cannot be sent between
processes as they are) are wrapped in the workers and unwrapped at the end.
`parallel_benchmark.R` times the current code and the prototype, with a
sequential plan, 2 and 4 R sessions (`multisession`, which works on all
systems) and 4 forked processes (`multicore`, not available on Windows), on 4
cores. All the plans give results identical to the current code.

Time in s, and speed-up of 4 sessions over the current code:

| method                | tracks x locations | current | futures, sequential | 2 sessions | 4 sessions | 4 forks | speed-up |
|-----------------------|-------------------:|--------:|--------------------:|-----------:|-----------:|--------:|---------:|
| `hr_tt_mcp()`         |           4 x 5000 |   0.045 |               0.120 |      0.192 |      0.238 |   0.245 |      0.2 |
|                       |           20 x 1000 |  0.081 |               0.215 |      0.207 |      0.279 |   0.291 |      0.3 |
|                       |           200 x 50 |   0.723 |               0.598 |      0.659 |      0.552 |   0.780 |      1.3 |
|                       |          1000 x 50 |   3.683 |               2.946 |      2.602 |      2.027 |   2.251 |      1.8 |
| `hr_tt_kde()`, levels |           4 x 5000 |   0.521 |               0.841 |      0.628 |      0.556 |   0.756 |      0.9 |
|                       |           20 x 1000 |  2.213 |               2.447 |      1.414 |      1.200 |   1.429 |      1.8 |
|                       |           200 x 50 |  23.183 |              21.778 |     12.720 |      7.328 |   8.425 |      3.2 |
|                       |          1000 x 50 | 112.554 |             114.796 |     63.620 |     36.149 |  36.410 |      3.1 |
| `hr_tt_kde()`, full UD |          4 x 5000 |   0.178 |               0.446 |      0.407 |      0.488 |   0.518 |      0.4 |
|                       |           20 x 1000 |  0.398 |               0.807 |      0.696 |      0.698 |   0.909 |      0.6 |
|                       |           200 x 50 |   2.650 |               6.184 |      3.770 |      3.120 |   3.455 |      0.8 |
| `hr_tt_locoh()`       |           4 x 5000 |   0.870 |               1.218 |      0.613 |      0.519 |   0.628 |      1.7 |
|                       |           20 x 1000 |  0.941 |               0.977 |      0.680 |      0.548 |   0.613 |      1.7 |
|                       |           200 x 50 |   1.507 |               1.656 |      1.066 |      0.817 |   1.212 |      1.8 |
|                       |          1000 x 50 |   6.179 |               6.011 |      4.262 |      2.990 |   3.611 |      2.1 |

(Both builds include the fix of the fixed costs of `hr_tt_mcp()` above. The
timings exclude starting the workers: starting 4 R sessions takes about
2.5 s, once per R session, and their first use of terra, for the first KDE,
a few more seconds; forks start in 0.2 s. The 4 sessions timing of the KDE of
4 x 5000 locations was taken again with warm workers.)

- `hr_tt_kde()` with `levels` gains the most: 3.1 to 3.2 times faster on 4
  cores with many tracks (113 s down to 36 s for 1000 tracks), as each track
  takes long (about 110 ms; see below).
- `hr_tt_locoh()` gains 1.7 to 2.1 times, with few long tracks or many short
  ones.
- `hr_tt_mcp()` only gains with hundreds of tracks (1.3 to 1.8 times, i.e.
  about 1.7 s for 1000 tracks), and is slower with few tracks, as the
  overhead of the futures (about 0.1 s per call, up to 0.3 s) exceeds the
  work.
- `hr_tt_kde()` returning full UDs is slower in parallel (0.4 to 0.8 times):
  the rasters must be wrapped, sent back and unwrapped, which costs more than
  computing them.
- The gains are well below 4 times, as the data and results must be sent
  between processes, and as part of the work (combining the tracks, the areas)
  remains sequential.

## Recommendation

Parallel processing is worth offering for `hr_tt_kde()` with `levels` and for
`hr_tt_locoh()`, as an opt-in that follows `future::plan()`. To leave the
default (sequential) use as fast as it is now, the loop should only go
through futures when the plan has more than one worker
(`future::nbrOfWorkers() > 1`), as the futures cost about 0.1 s (up to 0.3 s)
per call even with a sequential plan; full UDs should stay sequential. This requires adding
`future` and `doFuture` (or `future.apply`) to the dependencies, possibly as
suggested packages. For `hr_tt_mcp()`, the gain is too small to matter.

Before that, the fixed cost of `hr_tt_kde()` with `levels` (about 110 ms per
track, against 3 to 6 ms for `hr_tt_mcp()` and `hr_tt_locoh()`) is worth
reducing, which would benefit all users: a profile of 200 tracks of 50
locations shows 63% of the time in building the isopleths
(`hr_tt_ud_iso()`, per track), 22% in the KDE itself, 18% in looking up the
parameters of the CRS, and much of the rest in terra's own overheads.
