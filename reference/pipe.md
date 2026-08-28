# Pipe operator

See \`magrittr::pipe \\

## Usage

``` r
lhs %>% rhs
```

## Arguments

- lhs:

  A value or the magrittr placeholder.

- rhs:

  A function call using the magrittr semantics.

## Value

The result of calling `rhs(lhs)`.

## Examples

``` r
example_tt %>%
  event_time() %>%
  head()
#> [1] "2024-01-01 12:00:00 UTC" "2024-01-01 12:20:00 UTC"
#> [3] "2024-01-01 12:40:00 UTC" "2024-01-01 13:00:00 UTC"
#> [5] "2024-01-01 13:20:00 UTC" "2024-01-01 12:00:00 UTC"
```
