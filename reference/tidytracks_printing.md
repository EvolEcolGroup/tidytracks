# Enable or disable custom tidytracks printing

Controls whether objects of class `move2` use custom tidytracks printing
or the standard printing method supplied by `move2`.

## Usage

``` r
tidytracks_printing(value = NULL, sticky = TRUE)
```

## Arguments

- value:

  Either `TRUE`, `FALSE`, or `NULL`. `TRUE` registers custom tidytracks
  printing, `FALSE` registers standard move2 printing, and `NULL`
  reports which method is currently registered without changing
  anything.

- sticky:

  Whether the supplied setting should persist across R sessions. If
  `FALSE`, the method is changed only for the current R session. If
  `TRUE`, the supplied value is also saved in the user-specific
  tidytracks configuration directory. Defaults to `TRUE`.

## Value

If `value` is `NULL`, a logical scalar indicating whether tidytracks'
custom print method is currently registered. Otherwise, the supplied
value is returned invisibly after registration.

## Details

Calling `tidytracks_printing()` with no `value` directly inspects the
currently registered S3 method. It does not read the persistent
configuration file.

## Examples

``` r
if (FALSE) { # \dontrun{
tidytracks_printing()
tidytracks_printing(TRUE)
tidytracks_printing(FALSE)
tidytracks_printing(TRUE, sticky = FALSE)
tidytracks_printing(FALSE, sticky = FALSE)
} # }
```
