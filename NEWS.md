# tidytracks dev

* Rename functions to `hr_tt_` prefix to avoid name clashes with other packages.
* Allow group specific grids for `hr_tt_kde()`
* Add earth mover distance to `hr_tt_ud_overlap()`
* Ensure that all `track_*` functions return values in the same order as in the
  metadata.

# tidytracks 0.1.0

* Optimisation for `hr_tt_` functions and UD raster storage in tibbles to improve 
  speed of `hr_tt_ud_overlap()` 
* Minor bug fixes and documentation updates.
* Implement `hr_tt_ud_sum()` to sum multiple UDs.

# tidytracks 0.0.1

* Initial public release.
