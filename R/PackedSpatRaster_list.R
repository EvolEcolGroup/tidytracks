#' Create a PackedSpatRaster_list
#'
#' Accepts SpatRaster objects (packed automatically) or already-packed objects.
#' A lightweight S3 class wrapping a named or unnamed list of PackedSpatRaster
# objects.  Elements are stored wrapped and unpacked on the fly when accessed
# via [[ or $.

#'
#' @param ... SpatRaster / PackedSpatRaster objects, optionally named.
#'            A single plain list is also accepted.
#' @return A `PackedSpatRaster_list`.
#' @export
#' @examples
#' r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
#' r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
#' pl <- PackedSpatRaster_list(a = r1, b = r2)
PackedSpatRaster_list <- function(...) {
  dots <- list(...)

  # Accept a single bare list
  if (
    length(dots) == 1L &&
      is.list(dots[[1L]]) &&
      !inherits(dots[[1L]], "SpatRaster") &&
      !inherits(dots[[1L]], "PackedSpatRaster")
  ) {
    dots <- dots[[1L]]
  }

  if (length(dots) == 0L) {
    return(new_PackedSpatRaster_list(list()))
  }

  ok <- vapply(
    dots,
    function(x) {
      inherits(x, "SpatRaster") || inherits(x, "PackedSpatRaster")
    },
    logical(1L)
  )
  if (any(!ok)) {
    stop(
      "All elements must be SpatRaster or PackedSpatRaster objects. ",
      "Bad positions: ",
      paste(which(!ok), collapse = ", "),
      call. = FALSE
    )
  }

  packed <- lapply(dots, function(x) {
    if (inherits(x, "PackedSpatRaster")) x else terra::wrap(x)
  })

  new_PackedSpatRaster_list(packed)
}

# Low-level constructor — always receives a list of PackedSpatRasters
new_PackedSpatRaster_list <- function(packed) {
  structure(packed, class = c("PackedSpatRaster_list", "list"))
}


# Accessors

#' Returns SpatRaster by position or name from PackedSpatRaster_list
#'
#' `[[` returns a SpatRaster by position or name (unwrapping it automatically)
#' @param x A PackedSpatRaster_list.
#' @param i The index or name of the element to return.
#' @param ... unused, for compatibility with generic. Additional arguments are
#'   ignored.
#' @returns A SpatRaster object, unwrapped from the PackedSpatRaster.
#' @export
`[[.PackedSpatRaster_list` <- function(x, i, ...) {
  item <- NextMethod() # fetch the PackedSpatRaster from the plain list
  if (is.null(item)) return(NULL)
  terra::unwrap(item)
}

#' Returns SpatRaster by name from PackedSpatRaster_list
#'
#' `$` returns a SpatRaster by position or name (unwrapping it automatically)
#' @param x A PackedSpatRaster_list.
#' @param name The name of the element to return.
#' @returns A SpatRaster object, unwrapped from the PackedSpatRaster.
#' @export
`$.PackedSpatRaster_list` <- function(x, name) {
  item <- .subset2(x, name) # bypass S3 dispatch to avoid recursion
  if (is.null(item)) return(NULL)
  terra::unwrap(item)
}

#' Subset a PackedSpatRaster_list by position or name
#'
#' `[` subsets and returns a new PackedSpatRaster_list (still packed)
#' @param x A PackedSpatRaster_list.
#' @param i The indices or names of the elements to subset.
#' @param ... Additional arguments passed to `NextMethod()`, for compatibility
#'   with generic.
#' @export
`[.PackedSpatRaster_list` <- function(x, i, ...) {
  new_PackedSpatRaster_list(NextMethod())
}

#####################################
# Replacement operators
#####################################

#' Add SpatRaster by position or name to PackedSpatRaster_list
#'
#' `[[<-` stores a SpatRaster by position or name (wrapping it automatically)
#' @param x A PackedSpatRaster_list to modify.
#' @param i The index or name of the element to set.
#' @param value A SpatRaster or PackedSpatRaster to store at the specified name.
#'   If value is a SpatRaster, it will be automatically wrapped as a
#'   PackedSpatRaster before storage.
#' @export
`[[<-.PackedSpatRaster_list` <- function(x, i, value) {
  if (!is.null(value)) {
    if (inherits(value, "SpatRaster")) {
      value <- terra::wrap(value)
    }
  }
  new_PackedSpatRaster_list(NextMethod())
}


#' Add SpatRaster by name to PackedSpatRaster_list
#'
#' `$<-` stores a SpatRaster by name (wrapping it automatically)
#' @param x A PackedSpatRaster_list to modify.
#' @param name The name of the element to set.
#' @param value A SpatRaster or PackedSpatRaster to store at the specified name.
#'   If value is a SpatRaster, it will be automatically wrapped as a
#'   PackedSpatRaster before storage.
#' @export
`$<-.PackedSpatRaster_list` <- function(x, name, value) {
  x[[name]] <- value # delegate to [[<-
  x
}

#' Print a summary of the PackedSpatRaster_list
#'
#' Print a summary of the PackedSpatRaster_list, showing dimensions and CRS of
#' each element. This provides a quick overview of the contents of the list
#' without the overhead of unwrapping all rasters.
#' @param x A PackedSpatRaster_list to print.
#' @param ... Not used.
#' @return The original PackedSpatRaster_list, invisibly.
#' @export
print.PackedSpatRaster_list <- function(x, ...) {
  # check that ... is empty
  if (length(list(...)) > 0L) {
    warning("additional arguments ignored", call. = FALSE)
  }
  n <- length(x)
  nms <- names(x)

  cat("<PackedSpatRaster_list[", n, "]>\n", sep = "")

  if (n > 0L) {
    for (i in seq_len(n)) {
      r <- x[[i]]
      dims <- paste0(nrow(r), "x", ncol(r), "x", terra::nlyr(r))
      crs <- terra::crs(r, describe = TRUE)$name
      label <- if (!is.na(crs) && nzchar(crs)) crs else "no CRS"
      tag <- if (!is.null(nms) && nzchar(nms[i])) paste0("$", nms[i]) else
        paste0("[[", i, "]]")
      cat(sprintf("  %s <SpatRaster [%s] %s>\n", tag, dims, label))
    }
  }

  invisible(x)
}

#####################################
# 6. Coercion
#####################################

#' Unpack all rasters into a plain list of live SpatRasters
#' @param x PackedSpatRaster_list to convert
#' @param ... Not used.
#' @export
as.list.PackedSpatRaster_list <- function(x, ...) {
  # check that ... is empty
  if (length(list(...)) > 0L) {
    warning("additional arguments ignored", call. = FALSE)
  }
  lapply(unclass(x), terra::unwrap)
}

#' Coerce a plain list of SpatRasters to PackedSpatRaster_list
#'
#' This is a convenience function that allows users to easily convert a plain
#' list of SpatRasters to a PackedSpatRaster_list. It will check that all
#' elements of the list are SpatRasters and then wrap them as PackedSpatRasters
#' before creating the PackedSpatRaster_list. If the input is already a
#' PackedSpatRaster_list, it will simply return it unchanged.
#' @param x A list of SpatRasters or a PackedSpatRaster_list.
#' @return A PackedSpatRaster_list.
#' @export
#' @examples
#' r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
#' r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
#' lst <- list(r1, r2)
#' pl <- as_PackedSpatRaster_list(lst)

#'
as_PackedSpatRaster_list <- function(x) UseMethod("as_PackedSpatRaster_list")

#' @export
as_PackedSpatRaster_list.list <- function(x) PackedSpatRaster_list(x)

#' @export
as_PackedSpatRaster_list.PackedSpatRaster_list <- function(x) x
