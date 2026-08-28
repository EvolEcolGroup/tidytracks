# Write a tibble of tracks to CSV files

This function writes the event table and the metadata table of a
'tidy_tracks' object to CSV files (or one combined CSV file).

## Usage

``` r
tt_write_data(x, file_prefix, combined = FALSE)
```

## Arguments

- x:

  A `move2` object

- file_prefix:

  The file path to write the tables, with the prefix for the file names.
  The event table will be saved as '\<file_prefix\>\_events.csv' and the
  metadata table as '\<file_prefix\>\_metadata.csv'. If
  `combined = TRUE`, the combined table will be saved as
  '\<file_prefix\>\_combined.csv'.

- combined:

  Logical, whether to write a combined CSV file with both the event and
  metadata tables. Default is FALSE.

## Value

Invisibly, the result of the final
[`utils::write.csv()`](https://rdrr.io/r/utils/write.table.html) call;
this function is primarily called for its side effect of writing CSV
files.

## Examples

``` r
# Save to temp directory
tmp_prefix <- file.path(tempdir(), "example_tt_data")
tt_write_data(
  example_tt,
  tmp_prefix,
  combined = TRUE
  )
```
