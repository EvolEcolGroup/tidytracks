# Precompile the article on ctmm, as fitting the movement models takes too
# long to run when building the website. The article is knitted from
# ctmm_models.Rmd.orig into ctmm_models.Rmd, which contains the code with
# its output (and links to the figures, in figures/ctmm_models), so that
# pkgdown only needs to convert it to html.
#
# Run it from the root of the package, after editing ctmm_models.Rmd.orig or
# after changes to tidytracks or ctmm that affect the article, with the
# current version of tidytracks installed:
# Rscript vignettes/articles/code/precompile_ctmm_models.R
# and commit both ctmm_models.Rmd and the figures.

setwd("vignettes/articles")
# remove the old figures, so that figures of deleted chunks do not linger
unlink("figures/ctmm_models", recursive = TRUE)
# pkgdown sets this seed before rendering an article
set.seed(1014)
knitr::knit("ctmm_models.Rmd.orig", output = "ctmm_models.Rmd")
