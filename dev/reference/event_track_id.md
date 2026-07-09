# Return the track id of each event

This is a helper function to access the track id of each event in a
move2 object; it returns content of the column designated
"track_id_column" in the move2 object.

## Usage

``` r
event_track_id(x)
```

## Arguments

- x:

  A move2 object

## Value

a vector of track IDs of the same length as the number of events in `x`

## Examples

``` r
event_track_id(example_tt)
#>  [1] a a a a a b b b b b c c c c c
#> Levels: a b c
```
