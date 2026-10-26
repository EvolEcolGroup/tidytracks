# internal helpers shared by the wrappers around the suggested package
# move2utils. the wrappers follow the tidytracks conventions (event_* return
# one value per event, tt_* return the modified move2, track_* one value per
# track), so these helpers translate between those conventions and the way
# move2utils works: it returns its input with added columns, takes physical
# quantities as plain numbers, and draws plots and prints narration by default.

#' Check that move2utils is installed
#'
#' Functions that wrap `move2utils` call this first. `move2utils` is a
#' suggested package that is not on CRAN, so the error explains how to install
#' it from GitHub.
#'
#' @param fn Name of the calling function, used in the error message.
#' @returns `NULL`, invisibly; gives an error if `move2utils` is not installed.
#' @keywords internal
#' @noRd
check_move2utils <- function(fn) {
  # this is called before any other check, so that users without move2utils
  # learn how to install it rather than getting an error about their input
  if (!is_move2utils_installed()) {
    stop(
      fn, "() requires the suggested package 'move2utils'. ",
      "Install it with remotes::install_github('move2universe/move2utils')."
    )
  }
  invisible(NULL)
}

#' Check whether move2utils is installed (a separate function so that it can
#' be mocked in tests)
#' @keywords internal
#' @noRd
is_move2utils_installed <- function() {
  # requireNamespace() loads move2utils without attaching it: the wrappers
  # always call its functions with move2utils::
  requireNamespace("move2utils", quietly = TRUE)
}

#' Set the defaults used when tidytracks calls a move2utils function
#'
#' Many `move2utils` functions draw a plot and print a narrative by default.
#' tidytracks wrappers return values instead, so `plot = FALSE` and
#' `silent = TRUE` are set for any function that has these arguments, unless
#' they are already in `args`. `remove` is always set to `FALSE`, as the
#' wrappers match the results to the events of their input (the `tt_*()`
#' wrappers then remove events themselves).
#'
#' @param fn A `move2utils` function.
#' @param args A named list of arguments for `fn`.
#' @returns `args`, with `plot`, `silent` and `remove` set where relevant.
#' @keywords internal
#' @noRd
move2utils_args <- function(fn, args) {
  # the arguments are only added to functions that have them, as passing an
  # unknown argument to a move2utils function is an error
  fn_args <- names(formals(fn))
  # [[ ]] rather than $, as $ partially matches names (e.g. args$plot would
  # return an argument called plot_type)
  # a user can still ask for a plot or the narration, e.g. through the ... of
  # event_flag_outliers(), as these do not change the results
  if ("plot" %in% fn_args && is.null(args[["plot"]])) {
    args$plot <- FALSE
  }
  if ("silent" %in% fn_args && is.null(args[["silent"]])) {
    args$silent <- TRUE
  }
  # remove = TRUE would drop events from the output, which could then not be
  # matched to the events of x, so it is overridden even if the user set it
  if ("remove" %in% fn_args) {
    args$remove <- FALSE
  }
  args
}

#' The units expected by move2utils for its physical arguments
#'
#' `move2utils` functions take physical quantities as plain numbers, in the
#' units listed here (by argument name), whilst tidytracks uses `units`
#' objects.
#' @keywords internal
#' @noRd
move2utils_units <- c(
  # only arguments whose units are the same in every move2utils function
  # that has them are listed (checked in the move2utils documentation): times
  # are deliberately absent, as move2utils takes some in seconds and others
  # in minutes (e.g. time_step of mt_thin_time())
  v_max = "m/s",
  physiological_ceiling = "m/s",
  speed_threshold = "m/s",
  location_error = "m",
  residual_floor = "m",
  step_floor = "m",
  jitter = "m",
  min_leg = "m",
  mass = "kg"
)

#' Convert units objects to the numbers expected by move2utils
#'
#' The physical arguments of `move2utils` functions (see `move2utils_units`)
#' must be given as `units` objects, which are converted to numbers in the
#' units expected by `move2utils`. `NULL` and character values (e.g. the name
#' of a column for `location_error`, whose units are checked by the wrappers
#' with `location_error_column()`) are passed unchanged. Other arguments are
#' passed unchanged, except that `units` objects are rejected, as the units
#' that `move2utils` expects for them are not known (e.g. some times are in
#' seconds and others in minutes).
#'
#' @param args A named list of arguments.
#' @returns `args`, with `units` objects replaced by numbers.
#' @keywords internal
#' @noRd
units_to_move2utils <- function(args) {
  # list(...) has no names at all when no argument is named
  arg_names <- names(args)
  if (is.null(arg_names)) {
    arg_names <- rep("", length(args))
  }
  for (i in seq_along(args)) {
    arg <- args[[i]]
    # NA for unnamed arguments and for those not in the table
    expected <- unname(move2utils_units[arg_names[i]])
    if (is.na(expected)) {
      # move2utils expects plain numbers, and the units it expects for this
      # argument are not known here, so refuse rather than guess
      if (inherits(arg, "units")) {
        stop(
          "units objects are not supported for the argument '",
          arg_names[i], "'"
        )
      }
      next
    }
    # NULL is the move2utils default for most of these arguments (and
    # assigning NULL with [[<- would delete the argument), and a character
    # value names a column (location_error)
    if (is.null(arg) || is.character(arg)) {
      next
    }
    # plain numbers are refused, as in the rest of tidytracks, so that the
    # units are always explicit
    if (
      !inherits(arg, "units") ||
        !units::ud_are_convertible(units::deparse_unit(arg), expected)
    ) {
      stop(
        arg_names[i], " must be a units object with units convertible to ",
        expected, ", e.g. as_units(1, '", expected, "')"
      )
    }
    # mode = "standard" because the target units are in a variable
    args[[i]] <- as.numeric(units::set_units(arg, expected, mode = "standard"))
  }
  args
}

#' Get a column of location errors, checking its units
#'
#' Location errors can be given to the `move2utils` wrappers as the name of a
#' column of `x`, which must be a `units` object with units of length: a
#' column of plain numbers is rejected rather than assumed to be in metres.
#'
#' @param x A `move2` object.
#' @param col The name of the column.
#' @returns The column, a `units` object.
#' @keywords internal
#' @noRd
location_error_column <- function(x, col) {
  if (!col %in% names(x)) {
    stop("location_error ('", col, "') is not a column of x")
  }
  error <- x[[col]]
  if (
    !inherits(error, "units") ||
      !units::ud_are_convertible(units::deparse_unit(error), "m")
  ) {
    stop(
      "the column '", col, "' used for location_error must be a units ",
      "object with units of length: e.g. mutate(x, ", col, " = as_units(",
      col, ", 'm'))"
    )
  }
  error
}

#' Check that a move2 object is ordered by time within each track
#'
#' Most `move2utils` functions work on the steps between consecutive events,
#' and assume that the events of each track are stored together and ordered by
#' time. Rather than reordering behind the scenes, the wrappers require an
#' ordered object and suggest [tt_order_time()].
#'
#' @param x A `move2` object.
#' @returns `NULL`, invisibly; gives an error if `x` is not ordered by time
#'   within each track.
#' @keywords internal
#' @noRd
check_time_ordered <- function(x) {
  # reordering inside a wrapper would make the results of the event_*
  # functions harder to match to the events, so ordering is left to the user
  # mt_is_time_ordered() returns FALSE if the times are not in order, but gives
  # an error if the events of a track are not stored together; both cases are
  # fixed by tt_order_time(), so they get the same error. callers check that x
  # is a move2 object first, so no other error is expected here
  # duplicated times are allowed (the default of mt_is_time_ordered())
  ordered <- tryCatch(
    move2::mt_is_time_ordered(x),
    error = function(e) FALSE
  )
  if (!isTRUE(ordered)) {
    stop(
      "x must be ordered by time within each track; ",
      "use tt_order_time(x) to order it"
    )
  }
  invisible(NULL)
}

#' Check that distances can be computed in metres from the coordinates
#'
#' `move2utils` computes distances from the coordinates directly: great circle
#' distances for geographic coordinates, and Euclidean distances, taken to be
#' in metres, for projected coordinates. Projected coordinates in other units
#' (e.g. US survey feet) would silently give wrong distances and speeds, so
#' they are rejected.
#'
#' @param x A `move2` object, with a CRS.
#' @returns `NULL`, invisibly; gives an error if `x` has a projected CRS whose
#'   units are not metres.
#' @keywords internal
#' @noRd
check_metric_crs <- function(x) {
  if (!sf::st_is_longlat(x) && !identical(sf::st_crs(x)$units_gdal, "metre")) {
    stop(
      "x must have a geographic coordinate reference system, or a projected ",
      "one in metres (see sf::st_transform())"
    )
  }
  invisible(NULL)
}

#' Call a move2utils function and return event-level results
#'
#' Calls a `move2utils` function that returns its input `move2` object with
#' added columns, and returns the requested columns matched to the events of
#' `x`. `move2utils` gives an error for events without a location, whilst
#' tidytracks allows them: they are not passed to `fn`, and get `NA`.
#'
#' @param x A `move2` object.
#' @param fn A `move2utils` function whose first argument is a `move2` object
#'   and which returns that object with added columns.
#' @param ... Further arguments passed to `fn`.
#' @param cols Character vector of the columns of the output of `fn` to return.
#' @param time_ordered Logical, whether `fn` requires the events to be ordered
#'   by time within each track (see `check_time_ordered()`).
#' @returns A tibble with one row per event of `x` (in the same order) and the
#'   columns `cols`.
#' @keywords internal
#' @noRd
call_move2utils <- function(x, fn, ..., cols, time_ordered = TRUE) {
  # time_ordered = FALSE is only for move2utils functions that sort the
  # events themselves; the output check below still requires them to return
  # the events in the order they were given
  if (time_ordered) {
    check_time_ordered(x)
  }
  # dropping events keeps the order of the others, so the subset is still
  # ordered by time within each track
  located <- !sf::st_is_empty(x)
  args <- move2utils_args(fn, c(list(x[located, ]), list(...)))
  res <- do.call(fn, args)
  # the results are matched to the events by position, so check that
  # move2utils kept every event, in order; comparing the times catches
  # dropped, added and reordered events (a different length is not identical)
  if (!identical(move2::mt_time(res), move2::mt_time(x)[located])) {
    stop("move2utils did not return one row for each event, in order")
  }
  missing_cols <- setdiff(cols, names(res))
  if (length(missing_cols) > 0) {
    stop(
      "move2utils did not return the column(s): ",
      paste(missing_cols, collapse = ", ")
    )
  }
  # position in res of each event of x, NA for the events that were not
  # passed to move2utils; indexing each column with it keeps its class (e.g.
  # units or POSIXct), and the columns are taken one by one with [[ ]] as
  # res[cols] would keep the geometry of the sf object
  idx <- match(seq_len(nrow(x)), which(located))
  out <- lapply(cols, function(col) res[[col]][idx])
  names(out) <- cols
  tibble::as_tibble(out)
}
