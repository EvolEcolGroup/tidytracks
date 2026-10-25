#' Estimate the maximum speed of an animal from its body mass
#'
#' This function predicts the maximum speed that an animal of a given body
#' mass can physically reach, using the allometric scaling law of Hirt et al.
#' (2017) for flying, running and swimming animals. The prediction can be used
#' as `max_speed` in [event_flag_mcconnell()] and [tt_clean_mcconnell()] when a
#' species-specific maximum speed is not available. It is a wrapper around
#' [move2utils::v_phys_estimate()], which requires the suggested package
#' `move2utils` (install it with
#' `remotes::install_github("move2universe/move2utils")`).
#'
#' The model predicts maximum horizontal burst speeds: it is a ceiling on what
#' an animal can do, not its usual travel speed. Specialist sprinters (e.g.
#' cheetahs) can exceed the prediction, so a published species-specific
#' maximum should be preferred when available. See
#' [move2utils::v_phys_estimate()] for the details of the model and its
#' caveats.
#'
#' @param mass Body mass, as a `units` object (e.g. `as_units(4, "kg")`). It
#'   can be a vector, e.g. to obtain a prediction for each track from a column
#'   of the metadata; missing values give `NA`.
#' @param mode The mode of locomotion, one of "flying", "running" or
#'   "swimming". Either a single value or one value per element of `mass`.
#' @param ci_level The level of the confidence interval returned in the
#'   attribute `ci`.
#' @returns A `units` vector of maximum speeds in m/s, with one value per
#'   element of `mass`. The attribute `ci` is a matrix with columns `lower`
#'   and `upper`, and one row per element of `mass`, giving the confidence
#'   interval (in m/s) reflecting the uncertainty in the parameters of the
#'   model (not the variation among species).
#' @references Hirt, M. R., Jetz, W., Rall, B. C. & Brose, U. (2017). A
#'   general scaling law reveals why the largest animals are not the fastest.
#'   *Nature Ecology & Evolution*, 1, 1116-1122.
#'   \doi{10.1038/s41559-017-0241-4}
#' @export
#' @examplesIf requireNamespace("move2utils", quietly = TRUE)
#' # maximum speed of a 4 kg running animal
#' max_speed <- max_speed_allometric(as_units(4, "kg"), mode = "running")
#' max_speed
#' # use it to clean a track
#' tt_clean_mcconnell(example_tt, max_speed = max_speed)
max_speed_allometric <- function(
  mass,
  mode = c("flying", "running", "swimming"),
  ci_level = 0.95
) {
  check_move2utils("max_speed_allometric") # nolint: object_usage_linter.
  # mass must carry its units (a plain number is ambiguous between kg and g,
  # a factor of 1000), and is converted to kg, the units of move2utils
  if (
    !inherits(mass, "units") || length(mass) == 0 ||
      !units::ud_are_convertible(units::deparse_unit(mass), "kg")
  ) {
    stop(
      "mass must be a units object with units of mass: ",
      "e.g. as_units(4, 'kg')"
    )
  }
  mass <- units::drop_units(units::set_units(mass, "kg", mode = "standard"))
  # the default of mode only lists the choices: the predictions differ
  # several-fold between modes, so there is no sensible default
  if (missing(mode)) {
    stop("mode must be provided: one of 'flying', 'running' or 'swimming'")
  }
  if (!length(mode) %in% c(1, length(mass))) {
    stop("mode must be a single value or have the same length as mass")
  }
  # match.arg() is applied element by element, as with several.ok = TRUE it
  # would silently drop the values that do not match
  mode <- vapply(
    rep_len(mode, length(mass)),
    match.arg,
    character(1),
    choices = c("flying", "running", "swimming"),
    USE.NAMES = FALSE
  )

  # v_phys_estimate() only takes a single mass and mode, so it is called for
  # each element; it validates mass (positive) and ci_level itself, and warns
  # when mass is outside the range of the data of Hirt et al. (2017)
  estimates <- Map(
    function(m, md) {
      # a missing mass (e.g. in a column of the metadata) gives NA rather than
      # an error from move2utils
      if (is.na(m)) {
        return(structure(NA_real_, ci = c(NA_real_, NA_real_)))
      }
      move2utils::v_phys_estimate(mass = m, mode = md, ci_level = ci_level)
    },
    mass,
    mode
  )
  # each estimate is a number in m/s with attributes (ci, km/h, ...), which
  # as.numeric() drops
  speed <- units::as_units(
    vapply(estimates, as.numeric, numeric(1)),
    "m/s"
  )
  # the ci attribute of each estimate is an unnamed vector (lower, upper)
  ci <- do.call(rbind, lapply(estimates, attr, "ci"))
  colnames(ci) <- c("lower", "upper")
  attr(speed, "ci") <- ci
  speed
}
