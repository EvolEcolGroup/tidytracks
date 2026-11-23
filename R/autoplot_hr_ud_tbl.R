#' Autoplot a tibble of utilisation distributions
#'
#' This autoplot function can be used to plot all or a subset of UDs from a
#' tibble of UDs created by [hr_tt_kde()]. The UDs are identified by the
#' columns before `method` (the grouping variables used to estimate them), or
#' else by the first column of the tibble. The layout of the plots can be
#' specified with the `layout` argument, and it is assembled with `patchwork`.
#'
#' @param object A tibble of utilisation distributions created by kde of class
#'   `hr_tt_ud_tbl` as created with [hr_tt_kde()].
#' @param id_to_plot Integer or character, the position or id of the
#'   utilisation distributions to plot. If `NULL`, all utilisation
#'   distributions in the tibble are plotted. The ids are the values of the
#'   columns that identify the UDs (separated by "_" if there are several, with
#'   locations written as WKT, as in [hr_tt_ud_overlap()]).
#' @param layout A vector of length 2, the number of rows and columns in the
#'   plot layout. If `NULL`, the layout is determined automatically.
#' @param ... Not used.
#' @return A patchwork plot object created with [patchwork::wrap_plots()]. When
#'   one utilisation distribution is selected, the result is a single-panel
#'   plot composition; when multiple utilisation distributions are selected,
#'   the result is a multi-panel plot composition.
#' @importFrom ggplot2 autoplot
#' @export
#' @examples
#' # project example_tt (in longitude/latitude) to an equal-area projection
#' example_proj <- sf::st_transform(example_tt, "+proj=laea +lon_0=-1 +lat_0=0")
#' example_kde <- hr_tt_kde(example_proj)
#' library(ggplot2)
#' autoplot(example_kde)
autoplot.hr_tt_ud_tbl <- function(
  object,
  id_to_plot = NULL,
  layout = NULL,
  ...
) {
  # Work with a plain list locally while preserving a loaded object's packing.
  object <- hr_tt_ud_unwrap(object) # nolint: object_usage_linter.
  ## Get appropriate ids to plot
  # the ids of the UDs are the labels of their keys, i.e. of the columns
  # before `method` (the grouping variables of the hr_tt_* functions), or of
  # the first column of a table without them (as in hr_tt_ud_overlap())
  key_cols <- hr_key_columns(object) # nolint: object_usage_linter.
  ids <- hr_group_labels(object[key_cols]) # nolint: object_usage_linter.
  # check that the ids are unique
  if (anyDuplicated(ids) > 0) {
    stop(
      "the column(s) that identify the UDs (",
      paste0("'", key_cols, "'", collapse = ", "),
      ") must have unique id values"
    )
  }

  if (!is.null(id_to_plot)) {
    # if it is numeric, get the appropriate labels
    if (is.numeric(id_to_plot)) {
      id_to_plot <- ids[id_to_plot]
    }
    # check that all id_to_plot are ids of the UDs
    if (!all(id_to_plot %in% ids)) {
      stop("all id_to_plot must be ids of the UDs in the tibble")
    }
    # subset the rows directly: a filter() would fail on a grouped tibble
    # (e.g. from hr_tt_ud_sum()), as it is evaluated by group
    object <- object[ids %in% id_to_plot, ]
  } else {
    id_to_plot <- ids
  }

  ## Sort out layout

  # if layout is null, create a ncol and nrow, such that the plot has a ratio
  # of 3 rows to 2 columns
  if (is.null(layout)) {
    n <- length(id_to_plot)
    nrow <- ceiling(sqrt(n * 3 / 2))
    ncol <- ceiling(n / nrow)
    layout <- c(nrow, ncol)
  }

  # check that layout is a vector of length 2
  if (!is.null(layout) && length(layout) != 2) {
    stop("layout must be a vector of length 2")
  }

  # create a list of plots
  plot_list <- lapply(object$ud, plot_raster)
  p <- patchwork::wrap_plots(plot_list, nrow = layout[1], ncol = layout[2])

  return(p)
}

plot_raster <- function(r) {
  # Create the ggplot object using tidyterra
  p <- ggplot2::ggplot() +
    tidyterra::geom_spatraster(data = r) +
    ggplot2::labs(x = "longitude", y = "latitude") +
    ggplot2::theme_minimal()
  return(p)
}
