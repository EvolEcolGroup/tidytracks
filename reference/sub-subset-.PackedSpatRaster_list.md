# Add SpatRaster by position or name to PackedSpatRaster_list

`[[<-` stores a SpatRaster by position or name (wrapping it
automatically)

## Usage

``` r
# S3 method for class 'PackedSpatRaster_list'
x[[i]] <- value
```

## Arguments

- x:

  A PackedSpatRaster_list to modify.

- i:

  The index or name of the element to set.

- value:

  A SpatRaster or PackedSpatRaster to store at the specified name. If
  value is a SpatRaster, it will be automatically wrapped as a
  PackedSpatRaster before storage.
