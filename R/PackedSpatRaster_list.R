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
#' @examples
#' r1 <- terra::rast(nrows = 4, ncols = 4, vals = 1:16, crs = "EPSG:4326")
#' r2 <- terra::rast(nrows = 4, ncols = 4, vals = rnorm(16))
#' pl <- PackedSpatRaster_list(a = r1, b = r2)
PackedSpatRaster_list <- function(...) {
  dots <- list(...)
  
  # Accept a single bare list
  if (length(dots) == 1L &&
      is.list(dots[[1L]]) &&
      !inherits(dots[[1L]], "SpatRaster") &&
      !inherits(dots[[1L]], "PackedSpatRaster")) {
    dots <- dots[[1L]]
  }
  
  if (length(dots) == 0L) {
    return(new_PackedSpatRaster_list(list()))
  }
  
  ok <- vapply(dots, function(x) {
    inherits(x, "SpatRaster") || inherits(x, "PackedSpatRaster")
  }, logical(1L))
  if (any(!ok)) {
    stop(
      "All elements must be SpatRaster or PackedSpatRaster objects. ",
      "Bad positions: ", paste(which(!ok), collapse = ", "),
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

#' [[ unwraps and returns a single live SpatRaster
#' @export
`[[.PackedSpatRaster_list` <- function(x, i, ...) {
  item <- NextMethod()          # fetch the PackedSpatRaster from the plain list
  if (is.null(item)) return(NULL)
  terra::unwrap(item)
}

#' $ unwraps and returns a single live SpatRaster by name
#' @export
`$.PackedSpatRaster_list` <- function(x, name) {
  item <- .subset2(x, name)    # bypass S3 dispatch to avoid recursion
  if (is.null(item)) return(NULL)
  terra::unwrap(item)
}

#' [ subsets and returns a new PackedSpatRaster_list (still packed)
#' @export
`[.PackedSpatRaster_list` <- function(x, i, ...) {
  new_PackedSpatRaster_list(NextMethod())
}


# Replacement operators

#' [[<- stores a SpatRaster (wrapping it automatically)
#' @export
`[[<-.PackedSpatRaster_list` <- function(x, i, value) {
  if (!is.null(value)) {
    if (!inherits(value, "SpatRaster") && !inherits(value, "PackedSpatRaster")) {
      # this is a strange special case raised every so often by terra
      if (value == "<S4 class ‘SpatRaster’ [package “terra”] with 1 slot>"){
        NextMethod()
      }
      stop("value must be a SpatRaster or PackedSpatRaster.", call. = FALSE)
    }
    value <- if (inherits(value, "PackedSpatRaster")) value else terra::wrap(value)
  }
  new_PackedSpatRaster_list(NextMethod())
}

#' $<- stores a SpatRaster by name (wrapping it automatically)
#' @export
`$<-.PackedSpatRaster_list` <- function(x, name, value) {
  x[[name]] <- value   # delegate to [[<-
  x
}


# Print / format 

#' @export
print.PackedSpatRaster_list <- function(x, ...) {
  n   <- length(x)
  nms <- names(x)
  
  cat("<PackedSpatRaster_list[", n, "]>\n", sep = "")
  
  if (n > 0L) {
    for (i in seq_len(n)) {
      r     <- terra::unwrap(x[[i]])
      dims  <- paste0(nrow(r), "x", ncol(r), "x", terra::nlyr(r))
      crs   <- terra::crs(r, describe = TRUE)$name
      label <- if (!is.na(crs) && nzchar(crs)) crs else "no CRS"
      tag   <- if (!is.null(nms) && nzchar(nms[i])) paste0("$", nms[i]) else paste0("[[", i, "]]")
      cat(sprintf("  %s <SpatRaster [%s] %s>\n", tag, dims, label))
    }
  }
  
  invisible(x)
}


# 6. Coercion

#' Unpack all rasters into a plain list of live SpatRasters
#' @export
as.list.PackedSpatRaster_list <- function(x, ...) {
  lapply(unclass(x), terra::unwrap)
}

#' Coerce a plain list of SpatRasters to PackedSpatRaster_list
#' @export
as_PackedSpatRaster_list <- function(x, ...) UseMethod("as_PackedSpatRaster_list")

#' @export
as_PackedSpatRaster_list.list <- function(x, ...) PackedSpatRaster_list(x)

#' @export
as_PackedSpatRaster_list.PackedSpatRaster_list <- function(x, ...) x


