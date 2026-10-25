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
  fn_args <- names(formals(fn))
  if ("plot" %in% fn_args && is.null(args$plot)) {
    args$plot <- FALSE
  }
  if ("silent" %in% fn_args && is.null(args$silent)) {
    args$silent <- TRUE
  }
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
#' of a column for `location_error`) are passed unchanged. Other arguments are
#' passed unchanged, except that `units` objects are rejected, as the units
#' that `move2utils` expects for them are not known (e.g. some times are in
#' seconds and others in minutes).
#'
#' @param args A named list of arguments.
#' @returns `args`, with `units` objects replaced by numbers.
#' @keywords internal
#' @noRd
units_to_move2utils <- function(args) {
  arg_names <- names(args)
  if (is.null(arg_names)) {
    arg_names <- rep("", length(args))
  }
  for (i in seq_along(args)) {
    arg <- args[[i]]
    expected <- if (arg_names[i] %in% names(move2utils_units)) {
      move2utils_units[[arg_names[i]]]
    } else {
      NA_character_
    }
    if (is.na(expected)) {
      if (inherits(arg, "units")) {
        stop(
          "units objects are not supported for the argument '",
          arg_names[i], "'"
        )
      }
      next
    }
    if (is.null(arg) || is.character(arg)) {
      next
    }
    if (
      !inherits(arg, "units") ||
        !units::ud_are_convertible(units::deparse_unit(arg), expected)
    ) {
      stop(
        arg_names[i], " must be a units object with units convertible to ",
        expected, ", e.g. as_units(1, '", expected, "')"
      )
    }
    args[[i]] <- as.numeric(units::set_units(arg, expected, mode = "standard"))
  }
  args
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
  # mt_is_time_ordered() returns FALSE if the times are not in order, but gives
  # an error if the events of a track are not stored together
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
  if (time_ordered) {
    check_time_ordered(x)
  }
  located <- !sf::st_is_empty(x)
  args <- move2utils_args(fn, c(list(x[located, ]), list(...)))
  res <- do.call(fn, args)
  if (
    nrow(res) != sum(located) ||
      !identical(move2::mt_time(res), move2::mt_time(x)[located])
  ) {
    stop("move2utils did not return one row for each event, in order")
  }
  missing_cols <- setdiff(cols, names(res))
  if (length(missing_cols) > 0) {
    stop(
      "move2utils did not return the column(s): ",
      paste(missing_cols, collapse = ", ")
    )
  }
  # fill in the events that were not passed to move2utils with NA (indexing
  # each vector keeps its class, e.g. units or POSIXct)
  out <- lapply(cols, function(col) {
    values <- res[[col]]
    matched <- values[rep(NA_integer_, nrow(x))]
    matched[located] <- values
    matched
  })
  names(out) <- cols
  tibble::as_tibble(out)
}
