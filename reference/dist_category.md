# Create a categorical distance matrix

`dist_category()` takes a factor vector and returns a pairwise distance
matrix indicating whether observations belong to different categories.

## Usage

``` r
dist_category(x)
```

## Arguments

- x:

  A factor vector.

## Value

A numeric matrix with one row and one column for each element of `x`. If
`x` has names, they are used as row and column names.

## Details

The returned matrix contains:

- `0` when two observations are in the same category

- `1` when two observations are in different categories

- `NA` when either observation has a missing value

## See also

[`same_category()`](https://evolecolgroup.github.io/tidytracks/reference/same_category.md)

## Examples

``` r
group <- factor(c("A", "A", "B", "C"))

dist_category(group)
#>      [,1] [,2] [,3] [,4]
#> [1,]    0    0    1    1
#> [2,]    0    0    1    1
#> [3,]    1    1    0    1
#> [4,]    1    1    1    0

# Named input preserves names in the output matrix
named_group <- factor(c("red", "blue", "red"))
names(named_group) <- c("sample1", "sample2", "sample3")

dist_category(named_group)
#>         sample1 sample2 sample3
#> sample1       0       1       0
#> sample2       1       0       1
#> sample3       0       1       0

# Missing values return NA for comparisons involving the missing value
group_with_na <- factor(c("A", NA, "B"))
dist_category(group_with_na)
#>      [,1] [,2] [,3]
#> [1,]    0   NA    1
#> [2,]   NA   NA   NA
#> [3,]    1   NA    0
```
