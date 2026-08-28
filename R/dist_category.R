#' Create a categorical distance matrix
#'
#' `dist_category()` takes a factor vector and returns a pairwise distance
#' matrix indicating whether observations belong to different categories.
#'
#' The returned matrix contains:
#' \itemize{
#'   \item `0` when two observations are in the same category
#'   \item `1` when two observations are in different categories
#'   \item `NA` when either observation has a missing value
#' }
#'
#' @param x A factor vector.
#'
#' @return A numeric matrix with one row and one column for each element of `x`.
#' If `x` has names, they are used as row and column names.
#'
#' @seealso [same_category()]
#' @examples
#' group <- factor(c("A", "A", "B", "C"))
#'
#' dist_category(group)
#'
#' # Named input preserves names in the output matrix
#' named_group <- factor(c("red", "blue", "red"))
#' names(named_group) <- c("sample1", "sample2", "sample3")
#'
#' dist_category(named_group)
#'
#' # Missing values return NA for comparisons involving the missing value
#' group_with_na <- factor(c("A", NA, "B"))
#' dist_category(group_with_na)
#'
#' @export
dist_category <- function(x) {
  if (!is.factor(x)) {
    stop("`x` must be a factor vector.", call. = FALSE)
  }

  out <- outer(x, x, FUN = function(a, b) as.numeric(a != b))

  if (!is.null(names(x))) {
    dimnames(out) <- list(names(x), names(x))
  }

  out
}
