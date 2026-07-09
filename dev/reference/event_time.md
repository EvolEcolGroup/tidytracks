# Return the time of each event

This is a helper function to access the time of each event in a move2
object; it returns content of the column designated "time_column" in the
move2 object.

## Usage

``` r
event_time(x)
```

## Arguments

- x:

  A move2 object

## Value

a vector of times of the same length as the number of events in `x`

## Examples

``` r
event_time(example_tt)
#>  [1] "2024-01-01 12:00:00 UTC" "2024-01-01 12:20:00 UTC"
#>  [3] "2024-01-01 12:40:00 UTC" "2024-01-01 13:00:00 UTC"
#>  [5] "2024-01-01 13:20:00 UTC" "2024-01-01 12:00:00 UTC"
#>  [7] "2024-01-01 12:20:00 UTC" "2024-01-01 12:40:00 UTC"
#>  [9] "2024-01-01 13:00:00 UTC" "2024-01-01 13:20:00 UTC"
#> [11] "2024-01-01 12:00:00 UTC" "2024-01-01 12:20:00 UTC"
#> [13] "2024-01-01 12:40:00 UTC" "2024-01-01 13:00:00 UTC"
#> [15] "2024-01-01 13:20:00 UTC"
```
