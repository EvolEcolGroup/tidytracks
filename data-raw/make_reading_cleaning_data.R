# Make the datasets used in the article "Reading and cleaning data"
# (vignettes/articles/reading_cleaning.Rmd), and save them in
# vignettes/articles/data. Run from the root of the package.
#
# All the datasets are derived from the shags dataset of the main vignette
# (inst/extdata/shags_example.csv).

set.seed(123)
out_dir <- "vignettes/articles/data"

shags <- read.csv("inst/extdata/shags_example.csv")
# keep the columns that would come from the loggers and the field notes (the
# speed is computed from the locations in the article)
shags <- shags[, c(
  "bird_id", "date_time", "lon", "lat", "sex", "colony_lon", "colony_lat"
)]

################################################################################
# Small datasets with different date-time formats
################################################################################

# the first 5 locations of kb_17
shags_few <- shags[1:5, c("bird_id", "date_time", "lon", "lat")]
times <- as.POSIXct(shags_few$date_time, tz = "UTC")

# day/month/year dates, with the date and the time in separate columns
shags_dmy <- data.frame(
  bird_id = shags_few$bird_id,
  date = format(times, "%d/%m/%Y"),
  time = format(times, "%H:%M:%S"),
  lon = shags_few$lon,
  lat = shags_few$lat
)
write.csv(
  shags_dmy,
  file.path(out_dir, "shags_dates_dmy.csv"),
  row.names = FALSE
)

# month/day/year dates (all ambiguous, as the days are not after the 12th)
shags_mdy <- shags_few
shags_mdy$date_time <- format(times, "%m/%d/%Y %H:%M:%S")
write.csv(
  shags_mdy,
  file.path(out_dir, "shags_dates_mdy.csv"),
  row.names = FALSE
)

# ISO 8601 date-times, with a "T" between date and time, and a "Z" for UTC
shags_iso <- shags_few
shags_iso$date_time <- format(times, "%Y-%m-%dT%H:%M:%SZ")
write.csv(
  shags_iso,
  file.path(out_dir, "shags_dates_iso.csv"),
  row.names = FALSE
)

################################################################################
# A messy version of the full dataset, with failed fixes recorded at null island
# (0, 0) and duplicated records
################################################################################

# candidates for errors: events that are neither the first nor the last of
# their track (so that the tracks keep their start and end)
first_last <- !duplicated(shags$bird_id) |
  !duplicated(shags$bird_id, fromLast = TRUE)

# 35 consecutive failed fixes (70 minutes) while kb_43 flies away from the
# colony, which leave a gap of more than an hour in the track
failed_run <- which(shags$bird_id == "kb_43")[1076:1110]
# 20 isolated failed fixes, which make the sampling interval irregular
candidates <- setdiff(which(!first_last), failed_run)
failed_isolated <- sample(candidates, 20)
failed <- c(failed_run, failed_isolated)
shags$lon[failed] <- 0
shags$lat[failed] <- 0

# duplicated records, of events that are not failed fixes
candidates <- setdiff(candidates, failed_isolated)
dup_rows <- sample(candidates, 20)
# 5 records that duplicate the time stamp of an event, but are at null island
dup_null_island <- shags[dup_rows[1:5], ]
dup_null_island$lon <- 0
dup_null_island$lat <- 0
# 15 exact copies of an event
dup_exact <- shags[dup_rows[6:20], ]

# place each duplicate right after the original event
shags_raw <- rbind(shags, dup_null_island, dup_exact)
shags_raw <- shags_raw[order(c(seq_len(nrow(shags)), dup_rows)), ]

write.csv(
  shags_raw,
  file.path(out_dir, "shags_raw.csv"),
  row.names = FALSE
)
