# make the csv of buffalo tracks used in the ctmm article
# (vignettes/articles/ctmm_models.Rmd), from the buffalo dataset of ctmm
# (Getz et al. 2007, Cross et al. 2016); run from the root of the package

# we keep four buffalo, to keep the article quick to run: Cilla, Gabs and
# Mvubu, which share an area in the south of the park (so that the article
# can estimate the population home range of a group of three), and Pepper,
# whose sampling schedule changed
data(buffalo, package = "ctmm")
buffalo <- buffalo[c("Cilla", "Gabs", "Mvubu", "Pepper")]

# one row per location, with the id of the buffalo, the time (in UTC) and the
# coordinates (rounded to 6 decimals, i.e. about 0.1 m)
buffalo_df <- do.call(
  rbind,
  lapply(names(buffalo), function(id) {
    data.frame(
      buffalo_id = id,
      date_time = format(
        buffalo[[id]]$timestamp,
        "%Y-%m-%d %H:%M:%S",
        tz = "UTC"
      ),
      lon = round(buffalo[[id]]$longitude, 6),
      lat = round(buffalo[[id]]$latitude, 6)
    )
  })
)

# all the buffalo are adult females; these columns are repeated for each
# location, so tt_read_data() moves them to the metadata
buffalo_df$sex <- "female"
buffalo_df$age <- "adult"

write.csv(
  buffalo_df,
  "./vignettes/articles/data/buffalo_tracks.csv",
  row.names = FALSE
)
