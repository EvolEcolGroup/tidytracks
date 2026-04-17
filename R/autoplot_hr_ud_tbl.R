#' Autoplot a tibble of utilisation distributions
#'
#' This autoplot function can be used to plot all or a subset of UDs from a
#' tibble of UDs created by [tt_hr_kde()]. The first column of the tibble is
#' assumed to be an id column, which is used to identify the UDs to plot. The
#' layout of the plots can be specified with the `layout` argument, and it is
#' assembled with `patchwork`.
#'
#' @param object A tibble of utilisation distributions created by kde of class
#'   `hd_kde_tbl` as created with [tt_hr_kde()].
#' @param id_to_plot Integer or character, the id of the utilisation
#'   distribution to plot. If `NULL`, all utilisation distributions in the
#'   tibble are plotted. The first column of the tibble is assumed to be the id
#'   column.
#' @param layout A vector of length 2, the number of rows and columns in the
#'   plot layout. If `NULL`, the layout is determined automatically.
#' @param ... Not used.
#' @return A ggplot object.
#' @importFrom ggplot2 autoplot
#' @export

autoplot.hr_ud_tbl <- function(object, id_to_plot = NULL, layout = NULL,...) {
  
  ## Get appropriate ids to plot
  # check that the first column has unique values (which can be used as ids)
  if (length(unique(object[[1]])) != nrow(object)) {
    stop("the first column of the tibble must have unique id values")
  }
  
  if (!is.null(id_to_plot)) {
    # if it is numeric, get the appropriate labels
    if (is.numeric(id_to_plot)) {
      id_to_plot <- object[[1]][id_to_plot]
    }
    # check that all id_to_plot are in the first column of the tibble
    if (!all(id_to_plot %in% object[[1]])) {
      stop("all id_to_plot must be in the first column of the tibble")
    }
    object <- object %>%
      dplyr::filter(object[[1]] %in% id_to_plot)
  } else {
    id_to_plot <- object[[1]]
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

plot_raster <- function(r){  # Create the ggplot object using tidyterra
  p <- ggplot2::ggplot() +
    tidyterra::geom_spatraster(data = r) +
    ggplot2::labs(x = "longitude",
                  y = "latitude") +
    ggplot2::theme_minimal()
  return(p)
}
