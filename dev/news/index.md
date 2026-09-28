# Changelog

## tidytracks 0.2.0

- Rename functions to `hr_tt_` prefix to avoid name clashes with other
  packages. (NOTE the old names are still available for backwards
  compatibility, but will be deprecated in future releases.)
- Allow group specific grids for
  [`hr_tt_kde()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_kde.md)
- Add earth mover distance to
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)
- Ensure that all `track_*` functions return values in the same order as
  in the metadata.

## tidytracks 0.1.0

- Optimisation for `hr_tt_` functions and UD raster storage in tibbles
  to improve speed of
  [`hr_tt_ud_overlap()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_overlap.md)
- Minor bug fixes and documentation updates.
- Implement
  [`hr_tt_ud_sum()`](https://evolecolgroup.github.io/tidytracks/dev/reference/hr_tt_ud_sum.md)
  to sum multiple UDs.

## tidytracks 0.0.1

- Initial public release.
