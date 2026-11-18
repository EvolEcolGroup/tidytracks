# Code attribution and licence audit, November 2026

## Summary

- **Branch:** `attribution`, from `dev` at `6b3d855` (local, not pushed).
- **Fix commits:** 14, one per fix:
  - 2 rewrites of code copied from GPL-3-only packages;
  - 1 rewrite of code adapted from Wikibooks (CC BY-SA), which also cuts
    the memory of `hr_tt_locoh()` by up to 8x;
  - 4 commits that add copyright notices and credits;
  - 1 removal of scratch files;
  - 1 commit that adds source notes to two notebooks;
  - 5 follow-ups to the findings of R CMD check and of the verifier.
- **Findings not fixed:**
  - 4 data and figure items (Andrea: "we will deal with data later");
  - a few small attribution items;
  - method citations;
  - three possible speed-ups;
  - four bugs that the verifier found, which are also on `dev`.
- **Scope:** all of `R/`, `src/` and `tests/`, the vignettes and articles,
  README and logo, `inst/extdata`, `data/`, `data-raw/` and `dev_notes/`. The
  GitHub repository is public, so every tracked file counts, not only the
  built package.
- **Decisions** (Andrea, 18 Nov):
  - rewrite the GPL-3-only copies and the Wikibooks hull, with credit to the
    methods;
  - add the copyright notices (`inst/COPYRIGHTS`) and credits (Authors@R
    `ctb`);
  - remove `dev_notes/explorations/temp/`;
  - leave the data for later;
  - think about speed-ups while rewriting.

## Verification

| Check | Result |
|---|---|
| Identity of `hr_tt_mcp()` with `dev` | identical: 10,998 polygons of the helpers (benchmark, shag and boar tracks, 300 degenerate sets, levels 0 to 1), and `hr_tt_mcp()` on 10,000 tracks of 500 locations and 100 of 10,000 |
| Identity of LoCoH with `dev` | identical: 2,949 outputs of `locoh_cpp()` and `convex_hull_cpp()` (types k, r, a; with and without a buffer; union in C++ or by GEOS; 60 degenerate sets) and 2,000 random hulls |
| Test files of each fix | pass (`test_dist_fast`, `test_event_distance`, `test_event_flag_mcconnell`, `test_tt_split_trips`, `test_track_summary_stats`, `test_hr_tt_mcp`, `test_hr_tt_locoh`) |
| `lintr::lint_package()` | 0 lints, against the branch's own build (the 35 lints against the installed tidytracks 0.2.1 are all `object_usage_linter` on functions that version lacks) |
| `R CMD check` on `1d2cd34` (manica01, R 4.5.2) | 0 errors, 0 warnings, 2 NOTEs: move2utils is not installed (Rd cross-references), and the spelling test. The spelling NOTE flagged "PNPOLY", "JTS" and "gganimate's" from this branch, fixed in `cf5d2f8`; "WKT" and "multipolygon" come from `dev`. Examples and vignette OK |
| Full test suite on the tip `4828646` (installed, `NOT_CRAN=true`) | 51 files, 483 tests: 1,713 passed, 0 failed, 70 skipped (all for move2utils, not installed on manica01) |
| Independent verifier (every commit) | every commit checked, the follow-ups included. Identity confirmed independently: MCP, 2,972 polygons in 128 cases; LoCoH, 3,676 direct calls and 339 end-to-end cases. The hull code is clean in an ASan/UBSan build. Its findings: the stale Rd of `a78fb56` (fixed in `99e0d68`) and the follow-ups `9db4709`, `e7f0427` and `4828646`; three bugs on `dev` (below) |
| Cited DOIs | Karney (2013), Mohr (1947) and Andrew (1979) resolve to the right papers (Crossref) |

### Exceptions to "each test fails before the fix"

No fix changes behaviour, so none has a test that fails before it:

- the rewrites are checked by identity of outputs instead;
- the notices are comments and documentation.

The `dist_fast()` rewrite changes only the error message of an internal
function and drops its unused matrix form, so its tests were updated to
match.

## How the review was done

1. **Automatic scan.** The current CRAN sources were downloaded for trip,
   amt, adehabitatHR, adehabitatLT, KernSmooth, MASS, move, move2, ctmm,
   track2KBA, emdist, argosfilter, gganimate, tweenr, geodist, terra and sf,
   and move2utils from GitHub (`3c2c4a2`). Every tidytracks file was matched
   against them, by normalised identical lines (at least 30 characters) and
   shared runs of 12 tokens.
2. **Manual comparison, by area.** Three agents read and compared the code,
   to catch what a scan misses (translations, renamed variables, paraphrased
   documentation):
   - home ranges and the compiled code;
   - track operations and cleaning;
   - ctmm, plotting, printing, the vignettes and the figures.

   Further references: Shewchuk's `predicates.c`, the Wikibooks monotone chain
   page and its history, GEOS 3.12/3.13 and JTS, PNPOLY, ggplot2 3.5.1 and
   gganimate's LICENSE.
3. **History.** Each file with a likely upstream was traced back to its first
   version (`git log --follow`).
4. **Checks.** Every copy found was checked side by side with its source by
   the orchestrating session.
5. **Fixes.** Each fix is one commit; the speed-ups were benchmarked. An
   independent agent then verified every commit.

### Classes used for the findings

- **A:** verbatim or near-verbatim copy.
- **B:** close adaptation (same structure, renamed variables).
- **C:** own implementation of a published method or of upstream behaviour.
- **D:** call of the upstream package.

Only A and B raise copyright questions.

## Changes in behaviour to check before merging

- **`dist_fast()` (internal):** the matrix form is gone (no caller used it),
  and a length mismatch now gives "x1, y1, x2 and y2 must have the same
  length".
- **DESCRIPTION:** four contributors (`ctb`) and a `Copyright:` field. New
  file `inst/COPYRIGHTS`.
- **`hr_tt_locoh()`:** the same results with less memory.
  `hr_tt_mcp()`: the same results, faster.
- **`hr_tt_mcp()` with infinite coordinates:** a new error message, "the
  coordinates of the locations must be finite" (it was an error before too).

## Fixes by area

### Code copied from GPL-3-only packages (conflicts with `GPL (>= 3)`)

- [ ] `8b2960b` · `dist_fast()` — the argument checks (matrix form, messages)
  were copied verbatim from `trip::trackDistance.default()` (trip, GPL-3 only,
  M. D. Sumner). Now new code; the unused matrix form is dropped.
  *[licence; no change in the distances]*
- [ ] `d2d0a80` · `hr_tt_mcp()` (`mcp_one_group()`, `mcp_polygon()`, was
  `chull_mcp()`) — copied from `amt::hr_mcp()` (amt, GPL-3 only, J. Signer
  and contributors). Now new code, with identical results:
  - the type 7 quantile is computed inline, with one partial sort;
  - the polygon is built directly.

  15% faster on 10,000 tracks (4.23 s to 3.59 s) and 8% on 100 long tracks.
  The documentation now gives the rule for the levels (that of `amt`;
  `adehabitatHR` uses the distances, not their squares) and Mohr (1947).
  *[licence; speed]*

### Code adapted from Wikibooks (CC BY-SA)

- [ ] `1d2cd34` · `convex_hull()`, `strictly_convex_hull()` in
  `src/locoh.cpp` — adapted from the Wikibooks C++ monotone chain. Now new
  code for the same algorithm, with Andrew (1979) cited: one template sweep
  used for both boundaries and both turn tests.
  - **Memory:** each stored hull kept room for twice its neighbour set. The
    hulls now go in one flat vector, and the scratch vectors are reused.
  - **Identical results.** Peak memory, `dev` → `attribution`:
    - k = 10, 1 M locations: 1021 MB → 628 MB;
    - k = 50, 1 M locations: 2995 MB → 915 MB;
    - `"a"`, 100 k locations: 728 MB → 320 MB;
    - `"r"`, 100 k locations: 7062 MB → 830 MB.
  - **Time:** within noise for `"k"`, 5% faster for `"a"` and 17% faster for
    `"r"`.
  - **Large case:** `"r"` on 1 M locations was killed above 94 GB on `dev`;
    it now runs in 352 s and 32.6 GB.

  *[licence; memory]*

### Copyright notices and credits

- [ ] `a78fb56` · `shadow_wake_build()` — adapted from
  `gganimate::shadow_wake()` (MIT) without its notice. Now:
  - its copyright and permission notice is in the new `inst/COPYRIGHTS`;
  - `Copyright: see file COPYRIGHTS` in DESCRIPTION;
  - a file header;
  - T. L. Pedersen is `ctb`.

  *[licence]*
- [ ] `716bedc` · `point_in_ring()` (`src/convex_union.cpp`) — W. R.
  Franklin's PNPOLY, with no notice. Its notice is now verbatim in the source
  and in `inst/COPYRIGHTS`. *[licence]*
- [ ] `94d8b7c` · `intersection()` (`src/convex_union.cpp`) — a port of GEOS
  (LGPL 2.1, P. Ramsey), itself a port of JTS (EPL 2.0 / EDL 1.0, M. Davis).
  Their notices are now in the source and in `inst/COPYRIGHTS`; the GEOS code
  is conveyed under the GPL, as LGPL 2.1 section 3 allows. *[licence]*
- [ ] `99e0d68` · `filter_by_meta()`, `print_move2_tt()` — adapted from
  move2 (GPL (>= 3)). B. Kranstauber, K. Safi and A. K. Scharf are now
  `ctb`, and `print_move2_tt()` names the source. The commit also regenerates
  `tidytracks-package.Rd` for `a78fb56`. *[credit]*

### Follow-ups (R CMD check and verifier)

- [ ] `cf5d2f8` · `inst/WORDLIST`, NEWS — "PNPOLY" and "JTS" added to the
  word list, and "gganimate's" reworded: the spelling test of R CMD check
  flagged them. *[check]*
- [ ] `9db4709` · header of `R/shadow_wake_build.R` — it now lists all the
  changes from gganimate: the default of `wrap`, the skipped excluded layers
  and the positions of the alpha fade. *[accuracy]*
- [ ] `e7f0427` · `inst/COPYRIGHTS` — the JTS copyright line is now quoted
  verbatim ("martin Davis"). *[accuracy]*
- [ ] `23780f7` · header of `R/shadow_wake_build.R` — it now also names the
  replaced gganimate helpers: `vec_rbind0()`, `unique0()` and `mod_alpha()`.
  The first replacement drops gganimate's handling of ordered factors with
  different levels. *[accuracy]*
- [ ] `4828646` · `hr_tt_mcp()` — a clear error for infinite coordinates.
  - **Before:** on `dev` the error came from `quantile()`; after `d2d0a80`
    it came from `chull()` or `sort.int()` ("'partial' index 5 outside
    bounds"), each wrapped in "task 1 failed".
  - **Test:** fails on the old code and passes on the fix.

  *[error message]*

### Notes and scratch files

- [ ] `b50596c` · `dev_notes/explorations/temp/` removed. It held:
  - unattributed copies of `trip::speedfilter()` and `trackDistance()`;
  - adehabitatHR C-calling code;
  - the raw GPS and GLS data of a wandering albatross.

  *[licence; data]*
- [ ] `7d20565` · two notebooks in `dev_notes/explorations/old/` now name
  adehabitatHR as the source of their code. *[credit]*

## Findings not fixed

### Decision needed: data (left for later, Andrea 18 Nov)

- [ ] **Antarctic shag tracks.**
  - **Where:** `inst/extdata/shags_example.csv` (in the package; main
    vignette, examples of `tt_read_data()`), `data-raw/raw_csv/shag_*.csv`
    (which look like the raw data) and `vignettes/articles/data/shags_*.csv`.
  - **Missing:** no owner, permission or licence is recorded.
  - **Decision needed:** who owns them, on what terms they may be published,
    and how to cite them.
- [ ] **Wandering albatross tracks.**
  - **Where:** `vignettes/articles/data/wanderer_example_tracks.csv`, used by
    the animations article on the pkgdown site.
  - **Source:** probably the BirdLife Seabird Tracking Database, which needs
    the data owners' permission to redistribute.
  - **Decision needed:** permission and citation, or other data. The raw
    files in `temp/` are removed from the tree, but remain in the history.
- [ ] **Unused files in `inst/extdata/csv_files/`.**
  - `dataset_example_birdlife.csv` is an extract of Seabird Tracking
    Database dataset 1387.
  - `shag_tidytrack_sample_subset_old.csv` is an old copy of the shag data.
  - Nothing uses either file.
  - **Decision needed:** remove them (recommended).
- [ ] **Esri basemap.** `vignettes/articles/animations.Rmd:313` uses Esri
  World Ocean Base tiles with no credit. It needs a caption: "Esri, Garmin,
  GEBCO, NOAA NGDC, and other contributors", and "Powered by Esri".
- **Wild boar test data.** `tests/testthat/testdata/wildboar_tt.rds` comes
  from `adehabitatMA::puechabonsp` (GPL (>= 2); collected by D. Maillard). A
  note next to the data is good practice.
- **Logo.** The source of the seabird silhouette is not recorded (if it is
  from PhyloPic, it may need a credit).

### Small attribution items (no obligation)

- `src/exact_predicates.h`: adapted from Shewchuk's `predicates.c` (public
  domain). Shewchuk (1997) is cited; naming `predicates.c` would be good
  practice.
- `R/hr_tt_kde.R:622-631`: three lines from `KernSmooth::bkde2D()` (licence
  "Unlimited"); KernSmooth is named.
- `R/hr_tt_akde.R:437, 518-521`: one or two lines each from ctmm `kde.R`
  (GPL-3), commented "as in ctmm".
- ggplot2 parameter texts (MIT) in the `geom_*()` files, one or two
  sentences each. `@inheritParams ggplot2::geom_sf` would replace them.
- `R/event_flag_mcconnell.R`: the current code (`cc64433`) is our own; its
  first versions (from `731142e`, 2025-04) were copies of
  `trip::speedfilter()`.
  - Keep crediting trip. The roxygen's "a port of" could become "a
    reimplementation of".
  - Several "as in the original implementation" comments in
    `mcconnell_check_first_last()` refer to tidytracks' own earlier code, not
    to trip.
- **History:** the git history keeps the earlier copies, distributed on
  GitHub under GPL. These are the trip McConnell code (until 2026-10-28), the
  amt cumulative UD (until 2026-11) and the amt isopleths (until 2026-10-27).
  Nothing can be done short of rewriting history.

### Missing method citations

- **`hr_tt_kde()`:**
  - Worton (1989);
  - Silverman (1986) or Worton (1995), for the reference bandwidth (equal to
    `adehabitatHR` `href`);
  - Wand (1994), for binned KDE: named, not cited in full.
- **`hr_tt_ud_overlap()`:** Rubner, Tomasi & Guibas (2000), and Kranstauber,
  Smolla & Safi (2017), for the EMD.
- **`event_flag_mcconnell()`, `tt_clean_mcconnell()`:** McConnell, Chambers &
  Fedak (1992), *Antarctic Science* 4: 393-398. Also trip (Sumner,
  Wotherspoon & Hindell 2009).
- **`event_flag_outliers()`, `tt_clean_outliers()`,
  `track_suggest_max_speed()`:** the move2utils preprints (Safi 2026;
  Kranstauber, Safi & Scharf 2026).
- **`tt_split_trips()`:** Beal et al. (2021), track2KBA, where it matches
  `tripSplit()`.
- **The ctmm functions:**
  - Calabrese, Fleming & Gurarie (2016);
  - Fleming et al. (2014);
  - Fleming & Calabrese (2017), for `debias`;
  - Noonan et al. (2019), for speed;
  - Fleming et al. (2022), for population home ranges.
- **`src/locoh.cpp`:** a k-d tree reference (Bentley 1975; Friedman,
  Bentley & Finkel 1977).
- **`src/convex_union.cpp`:** a full reference for Leutenegger et al. (1997).
- **Main vignette:**
  - the references of Wanless et al. (1997) and Yukihisa et al. (2016) are
    missing;
  - McConnell (1992) is not cited;
  - it calls the `aeqd` projection "equal area", but `aeqd` is equidistant.

### Bugs found by the verifier (also on `dev`, not caused by this branch)

- [ ] **`hr_tt_mcp()` on some lon/lat data.**
  - **Error:** s2 rejects an MCP ring with "Loop 0 is not valid: Edge 9 is
    degenerate (duplicate vertex)". The verifier's case: lon/lat rounded to 3
    decimals, track t3 at level 0.9, vertex (9.995, 45.007) twice.
  - **Cause:** `grDevices::chull()` returned two vertices that s2 treats as
    the same point.
  - **Possible fix:** drop repeated vertices from the ring before building
    the polygon. This changes the output only in the cases that fail now.
  - **Decision needed:** fix it, with a test?
- [ ] **`hr_tt_locoh()` on rounded lon/lat.** s2 rejects an isopleth with
  "Loop 14 edge 22 crosses loop 20 edge 10". This happens on the union of
  the hulls for lon/lat data.
- **`locoh_cpp()` with no locations** reads `coverage[0]` of an empty vector.
  `hr_tt_locoh()` cannot reach it, as it requires 3 locations per group.
- **`shadow_wake_build(wrap = )` has no effect.** The wake never reaches back
  before frame 1, so `wrap = TRUE` changes nothing, and the `@param wrap`
  text copied from gganimate ("the first frame will get shadows from the
  end") does not apply. The fix is to drop the argument, or to document that
  it is ignored.

### Credits: consistency

- The authors of the adapted R code (gganimate, move2) are `ctb` in
  Authors@R. W. R. Franklin (PNPOLY), P. Ramsey (GEOS) and M. Davis (JTS)
  are covered by `Copyright:` and `inst/COPYRIGHTS` only.
- CRAN prefers `ctb` (or `cph`) for the authors of copied code, but accepts
  the `Copyright` field.
- **Decision needed:** add them as `cph`?

### Speed-ups not done

- [ ] **MCP in C++.**
  - **The cost now:** most of the time of `hr_tt_mcp()` on many short tracks
    is the R overhead of `grDevices::chull()`, about 40 µs of its 45 µs per
    call (the C algorithm takes 4 µs).
  - **The change:** compute the centroid, the quantile, the selection and
    the hull of every group and level in C++, with the monotone chain of
    `src/locoh.cpp`, and order the vertices as `chull()` does (by angle
    around their centroid). This would cut the per-group cost about tenfold
    (10,000 tracks of 500 locations: 3.6 s now, with about 2 s of it in the
    per-group work).
  - **The catch:** `chull()` (Eddy's algorithm) tests points against a
    slope-intercept line in floating point, so a few nearly collinear sets
    give different vertex sets. There were none in 2,535 hulls of real and
    simulated tracks, but 607 in 20,000 deliberately degenerate sets.
  - **Decision needed:** accept these differences (polygons that differ by
    vertices within rounding of an edge) for the speed?
- [ ] **LoCoH neighbour sets.** For `"r"` with large radii, the stored
  neighbour sets (one integer per neighbour per location) are now most of
  the memory (32.6 GB for 1 M locations). Computing each hull from its
  neighbours without storing them, and recomputing the neighbours of the
  hulls needed for the coverage, would remove most of it.
- [ ] **Adaptive LoCoH search.** About half of the time of `"a"` is the heap
  of the k-nearest-neighbour search, which is widened until the set is
  complete. A radius search on a bound of the distance, followed by a
  partial sort, may be faster.
