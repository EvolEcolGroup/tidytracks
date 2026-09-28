# Print move2 objects using tidytracks

Internal implementation used when custom tidytracks printing is enabled.

## Usage

``` r
print_move2_tt(x, ..., n = getOption("sf_max_print", default = 10L))
```

## Arguments

- x:

  An object of class `move2`.

- ...:

  Additional arguments passed to the next print method.

- n:

  Maximum number of rows to print. Defaults to the `sf_max_print`
  option, or 10 when that option is unset.

## Value

`x`, invisibly.

## Details

This function is registered dynamically as the S3
[`print()`](https://rdrr.io/r/base/print.html) method for class `move2`.
It must not have an `@export` or `@method` tag because doing so would
add an unconditional `S3method(print,move2)` entry to NAMESPACE.
