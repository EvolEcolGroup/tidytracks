# Note for Lizzie: data in tidytracks

November 2026. An audit of the code and licences of tidytracks (see
`code_review_attribution_2026-11.md`) found that, for the real tracking data
in the package and its repository, nothing records who owns them or under
what terms they can be published. The GitHub repository is public, and the
package would also be on CRAN if we submit it, so we need this for every
real data set. Could you help with the questions below?

## 1. Antarctic shag tracks

GPS tracks of Antarctic shags (*Leucocarbo bransfieldensis*), Killingbeck
Island, 2022. The main vignette says they are "based on real data, but
modified".

| file | used by | in the installed package |
|---|---|---|
| `inst/extdata/shags_example.csv` | the main vignette, and the examples of `tt_read_data()` | yes |
| `vignettes/articles/data/shags_*.csv` | the article "Reading and cleaning data" (derived from the file above) | no (website only) |
| `data-raw/raw_csv/shag_tidytrack_sample.csv`, `shag_tidytrack_meta.csv` | `data-raw/make_shags_tt.R`, which builds `shags_example.csv` | no, but public on GitHub |

We need to know:

- who owns the data (you, BAS, or others);
- whether we have permission to publish them, both the modified version and
  the files in `data-raw/raw_csv/`, which look like the original data;
- under which licence (e.g. CC BY 4.0 or CC0);
- how they should be cited (a paper, or a data set with a DOI);
- in what way they were modified, so that the documentation can say so.

## 2. Wandering albatross tracks

Ten wandering albatrosses from Bird Island, South Georgia (2007-08), each
tracked for about a year: `vignettes/articles/data/wanderer_example_tracks.csv`.
They are used by the article "Animations and maps", which is on the package
website. An old exploration notebook says they come from the BirdLife Seabird
Tracking Database, whose terms need the permission of the data owners to
redistribute data, and a citation.

We need to know:

- where they come from (Seabird Tracking Database dataset ID, or the data
  owner);
- whether we have permission to publish them, and how to cite them.

Otherwise we can replace them with other data (e.g. simulated tracks, or a
data set with an open licence).

**Related:** the raw GPS and GLS files of one wandering albatross
(`R5187420_gps.csv`, `R5187420_gls.deg`, and a zip of both) were in
`dev_notes/explorations/temp/`. They have been removed from the current files
(commit `b50596c` on branch `attribution`), but they are still in the git
history of the public repository. If they should not be public, we would
have to rewrite the history to remove them: please tell us.

## 3. Unused files in the package

Two files in `inst/extdata/csv_files/` are installed with the package, but
nothing uses them (no code, test, example or vignette):

- `dataset_example_birdlife.csv`: an extract of Seabird Tracking Database
  dataset 1387 (wandering albatross, Bird Island, 2009);
- `shag_tidytrack_sample_subset_old.csv`: an older version of the shag data.

We propose to delete both. Is there any reason to keep them?

## Already sorted (nothing to do)

- **African buffalo** (the ctmm article): from the `buffalo` data of ctmm,
  cited as ctmm asks (Getz et al. 2007; Cross et al. 2016).
- **Wild boar** (tests): from `adehabitatMA::puechabonsp` (D. Maillard). A
  credit note will be added next to the test data.
- **Esri basemap** (the animations article): a credit line will be added
  under the map and the animation.
