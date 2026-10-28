skip_if_not_installed("ctmm")

test_that("ctmm_tt_fit returns one model per track, in metadata order", {
  x <- ctmm_example_tt()
  # reverse the order of the tracks in the metadata
  show_meta(x) <- show_meta(x)[2:1, , drop = FALSE]
  fits <- suppressMessages(ctmm_tt_fit(x, model = "iid"))
  expect_s3_class(fits, "ctmm_tt_fit_tbl")
  expect_named(
    fits,
    c(
      "track", "model", "model_name", "aicc", "dof_area", "n_events",
      "t_start", "t_end", "fit_message"
    )
  )
  expect_equal(fits$track, show_meta(x)$track)
  expect_true(all(vapply(fits$model, inherits, logical(1), "ctmm")))
  expect_named(fits$model, c("Gabs", "Cilla"))
  expect_match(fits$model_name, "^IID")
  expect_equal(fits$n_events, c(100L, 100L))
  expect_equal(
    as.numeric(fits$t_start),
    c(
      min(as.numeric(event_time(x)[event_track_id(x) == "Gabs"])),
      min(as.numeric(event_time(x)[event_track_id(x) == "Cilla"]))
    )
  )
  expect_true(all(is.na(fits$fit_message)))
  # the information needed to use the models is stored with them
  expect_equal(attr(fits, "crs"), sf::st_crs(x))
  expect_equal(attr(fits, "track_id_column"), "track")
  expect_identical(attr(fits, "error_cols"), character(0))
  # dplyr verbs keep the class and attributes
  fits_sub <- dplyr::filter(fits, track == "Cilla")
  expect_s3_class(fits_sub, "ctmm_tt_fit_tbl")
  expect_equal(attr(fits_sub, "crs"), sf::st_crs(x))
})

test_that("ctmm_tt_fit fits the requested model", {
  x <- ctmm_example_tt(n = 60, tracks = "Cilla")
  expect_match(
    suppressMessages(ctmm_tt_fit(x, model = "ou"))$model_name,
    "^OU"
  )
  expect_match(
    suppressMessages(ctmm_tt_fit(x, model = "bm"))$model_name,
    "^BM"
  )
  # a template, and a named list of templates
  iso_iid <- ctmm::ctmm(isotropic = TRUE)
  expect_equal(
    suppressMessages(ctmm_tt_fit(x, model = iso_iid))$model_name,
    "IID"
  )
  expect_equal(
    suppressMessages(
      ctmm_tt_fit(x, model = list(Cilla = iso_iid))
    )$model_name,
    "IID"
  )
  expect_error(ctmm_tt_fit(x, model = "ouff"), "model must be one of")
  expect_error(
    ctmm_tt_fit(x, model = list(Gabs = iso_iid)),
    "names of the list"
  )
  expect_error(
    ctmm_tt_fit(x, model = list(iso_iid, iso_iid)),
    "one template per track"
  )
})

test_that("ctmm_tt_fit adds the error model to templates", {
  x <- ctmm_example_tt(n = 60, tracks = "Cilla")
  iso_iid <- ctmm::ctmm(isotropic = TRUE)
  fit_model <- function(...) suppressMessages(ctmm_tt_fit(x, ...))$model[[1]]
  # without error, the template is fitted as it is
  expect_false(any(fit_model(model = iso_iid)$error > 0))
  # with a uere (the buffalo have no DOP, which ctmm then assumes to be 1),
  # the error model is added to the template, which gives the same fit as a
  # template with an error model
  with_uere <- fit_model(model = iso_iid, uere = 10)
  expect_true(any(with_uere$error > 0))
  iso_iid_error <- ctmm::ctmm(isotropic = TRUE, error = TRUE)
  expect_equal(
    with_uere$loglike,
    fit_model(model = iso_iid_error, uere = 10)$loglike
  )
})

test_that("ctmm_tt_fit selects the best model with model = 'auto'", {
  skip_on_cran()
  x <- ctmm_example_tt(n = 60, tracks = "Cilla")
  fits <- suppressMessages(ctmm_tt_fit(x, candidates = TRUE))
  expect_true("candidates" %in% names(fits))
  # the selected model is the best candidate
  expect_equal(fits$model_name, names(fits$candidates$Cilla)[1])
  expect_gt(length(fits$candidates$Cilla), 1)
  # candidates are only available with model selection
  expect_warning(
    fits <- suppressMessages(
      ctmm_tt_fit(x, model = "iid", candidates = TRUE)
    ),
    "candidates are only returned"
  )
  expect_false("candidates" %in% names(fits))
})

test_that("ctmm_tt_fit keeps a row for the tracks that cannot be fitted", {
  x <- ctmm_example_tt(n = 20)
  # Gabs has a single location
  sf::st_geometry(x)[which(event_track_id(x) == "Gabs")[-1]] <- sf::st_point()
  expect_warning(
    fits <- suppressMessages(ctmm_tt_fit(x, model = "iid")),
    "could not be fitted for track\\(s\\) Gabs"
  )
  expect_equal(nrow(fits), 2)
  expect_null(fits$model$Gabs)
  expect_true(is.na(fits$model_name[2]))
  expect_false(is.na(fits$fit_message[2]))
  expect_true(is.na(fits$fit_message[1]))
  # a track without any location
  sf::st_geometry(x)[which(event_track_id(x) == "Gabs")] <- sf::st_point()
  expect_warning(
    fits <- suppressMessages(ctmm_tt_fit(x, model = "iid")),
    "could not be fitted"
  )
  expect_equal(fits$fit_message[2], "the track has no events with a location")
  expect_equal(fits$n_events, c(20L, 0L))
})

test_that("ctmm_tt_fit checks its inputs", {
  x <- ctmm_example_tt(n = 20)
  expect_error(ctmm_tt_fit(as.data.frame(x)), "must be a move2 object")
  expect_error(
    ctmm_tt_fit(sf::st_transform(x, 4326), model = "iid"),
    "projected coordinate reference system"
  )
  # grouping by track is allowed, by other variables is not
  expect_no_error(
    suppressMessages(ctmm_tt_fit(dplyr::group_by(x, track), model = "iid"))
  )
  x$period <- rep(c("a", "b"), length.out = nrow(x))
  expect_error(
    ctmm_tt_fit(dplyr::group_by(x, period), model = "iid"),
    "can only be grouped by its track id"
  )
  expect_error(ctmm_tt_fit(x, error = NA), "error must be TRUE or FALSE")
})

test_that("ctmm_tt_summary returns the parameters of each model", {
  x <- ctmm_example_tt(n = 60)
  fits <- suppressMessages(ctmm_tt_fit(x, model = "iid"))
  # the summary of a model with a home range time scale
  fits$model[[2]] <- suppressMessages(
    ctmm_tt_fit(filter_by_meta(x, track == "Gabs"), model = "ou")
  )$model[[1]]
  fits$model_name[2] <- "OU"
  summ <- ctmm_tt_summary(fits)
  expect_equal(summ$track, fits$track)
  expect_true(all(
    c(
      "area_low", "area_est", "area_high",
      "tau_position_low", "tau_position_est", "tau_position_high"
    ) %in% names(summ)
  ))
  expect_equal(units::deparse_unit(summ$area_est), "m2")
  expect_equal(units::deparse_unit(summ$tau_position_est), "s")
  # the IID model has no time scale
  expect_true(is.na(summ$tau_position_est[1]))
  expect_false(is.na(summ$tau_position_est[2]))
  # the values are those of ctmm
  ctmm_ci <- summary(fits$model[[1]], units = FALSE)$CI
  expect_equal(
    as.numeric(summ$area_est[1]),
    ctmm_ci["area (square meters)", "est"]
  )
  expect_true(all(summ$area_low <= summ$area_est))
  expect_true(all(summ$area_est <= summ$area_high))
  # a narrower confidence level gives narrower intervals
  summ_50 <- ctmm_tt_summary(fits, level = 0.5)
  expect_true(all(summ_50$area_low > summ$area_low))
  expect_error(ctmm_tt_summary(fits, level = 2), "level must be")
  expect_error(ctmm_tt_summary(fits, level = NA_real_), "level must be")
  expect_error(ctmm_tt_summary(tibble::tibble()), "created with ctmm_tt_fit")
})

test_that("ctmm_tt_summary gives units to all the time scales", {
  x <- ctmm_example_tt(n = 60, tracks = "Cilla")
  # an OUf model has a single time scale (tau, as tau_position equals
  # tau_velocity)
  fits <- suppressMessages(
    ctmm_tt_fit(x, model = ctmm::ctmm(tau = c(1, 1) * 3600))
  )
  expect_match(fits$model_name, "^OUf")
  summ <- ctmm_tt_summary(fits)
  expect_equal(units::deparse_unit(summ$tau_est), "s")
  # so does the period of circulation
  expect_equal(units::deparse_unit(ctmm_param_units(1, "circle")), "s")
})

test_that("ctmm_param_names converts the names of the ctmm parameters", {
  expect_equal(
    ctmm_param_names(c(
      "area (square meters)",
      "τ[position] (seconds)",
      "τ[velocity] (seconds)",
      "speed (meters/second)",
      "diffusion (square meters/second)"
    )),
    c("area", "tau_position", "tau_velocity", "speed", "diffusion")
  )
})
