# Create a categorical similarity matrix

`same_category()` takes a factor vector and returns a pairwise
similarity matrix indicating whether observations belong to the same
category.

## Usage

``` r
same_category(x)
```

## Arguments

- x:

  A factor vector.

## Value

A numeric matrix with one row and one column for each element of `x`. If
`x` has names, they are used as row and column names.

## Details

The returned matrix contains:

- `1` when two observations are in the same category

- `0` when two observations are in different categories

- `NA` when either observation has a missing value

## See also

[`dist_category()`](https://evolecolgroup.github.io/tidytracks/dev/reference/dist_category.md)

## Examples

``` r
group <- factor(c("A", "A", "B", "C"))

same_category(group)
#>      [,1] [,2] [,3] [,4]
#> [1,]    1    1    0    0
#> [2,]    1    1    0    0
#> [3,]    0    0    1    0
#> [4,]    0    0    0    1

# Named input preserves names in the output matrix
named_group <- factor(c("red", "blue", "red"))
names(named_group) <- c("sample1", "sample2", "sample3")

same_category(named_group)
#>         sample1 sample2 sample3
#> sample1       1       0       1
#> sample2       0       1       0
#> sample3       1       0       1

# Missing values return NA for comparisons involving the missing value
group_with_na <- factor(c("A", NA, "B"))
same_category(group_with_na)
#>      [,1] [,2] [,3]
#> [1,]    1   NA    0
#> [2,]   NA   NA   NA
#> [3,]    0   NA    1
```
