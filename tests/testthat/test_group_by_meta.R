test_that("group_by_meta groups by a column of the metadata", {
  toy_tt <- create_toy_tt()
  result <- group_by_meta(toy_tt, species)

  expect_s3_class(result, "move2")
  expect_s3_class(result, "grouped_df")
  expect_equal(dplyr::group_vars(result), "species")
  expect_equal(dplyr::n_groups(result), 2L)
  # species is moved from the metadata to the events
  expect_false("species" %in% names(show_meta(result)))
  expect_equal(result$species, rep(c("species_a", "species_b"), c(24, 6)))
  expect_equal(dplyr::group_size(result), c(24L, 6L))
  # the events are otherwise unchanged
  expect_equal(nrow(result), nrow(toy_tt))
  expect_equal(attr(result, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(result), sf::st_coordinates(toy_tt))
  expect_equal(result$bird_id, toy_tt$bird_id)
  # the other columns of the metadata stay there
  expect_equal(names(show_meta(result)), c("bird_id", "colony_sf"))
})

test_that("group_by_meta groups by an sfc column of the metadata", {
  toy_tt <- create_toy_tt_geo()
  result <- group_by_meta(toy_tt, colony_sf)

  expect_equal(dplyr::group_vars(result), "colony_sf")
  expect_equal(dplyr::n_groups(result), 2L)
  # colony_sf is moved to the events as an sfc column, with its crs
  expect_false("colony_sf" %in% names(show_meta(result)))
  expect_s3_class(result$colony_sf, "sfc")
  expect_equal(sf::st_crs(result$colony_sf), sf::st_crs(4326))
  expect_equal(
    sf::st_coordinates(result$colony_sf)[, "Y"],
    rep(c(10, 50), c(24, 6))
  )
  # the keys of the groups are the colonies
  keys <- dplyr::group_keys(result)
  expect_s3_class(keys$colony_sf, "sfc")
  expect_equal(sf::st_coordinates(keys$colony_sf)[, "Y"], c(10, 50))
  # the events keep their own geometry
  expect_equal(attr(result, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(result), sf::st_coordinates(toy_tt))
})

test_that("group_by_meta groups by new variables computed from the metadata", {
  toy_tt <- create_toy_tt_geo()
  result <- group_by_meta(
    toy_tt,
    north = sf::st_coordinates(colony_sf)[, "Y"] > 30
  )

  expect_equal(dplyr::group_vars(result), "north")
  expect_equal(result$north, rep(c(FALSE, TRUE), c(24, 6)))
  # the new variable is in the events only, and the column used to compute it
  # stays in the metadata
  expect_false("north" %in% names(show_meta(result)))
  expect_true("colony_sf" %in% names(show_meta(result)))
  expect_false("colony_sf" %in% names(result))

  # a new variable with the name of a column replaces it, as in dplyr
  result <- group_by_meta(toy_tt, species = toupper(species))
  expect_equal(result$species, rep(c("SPECIES_A", "SPECIES_B"), c(24, 6)))
  expect_false("species" %in% names(show_meta(result)))
})

test_that("group_by_meta groups by several variables of the metadata", {
  toy_tt <- create_toy_tt_geo()
  result <- group_by_meta(
    toy_tt,
    species,
    colony_sf,
    north = sf::st_coordinates(colony_sf)[, "Y"] > 30
  )
  expect_equal(dplyr::group_vars(result), c("species", "colony_sf", "north"))
  expect_equal(dplyr::n_groups(result), 2L)
  # the keys keep their types
  keys <- dplyr::group_keys(result)
  expect_equal(keys$species, c("species_a", "species_b"))
  expect_s3_class(keys$colony_sf, "sfc")
  expect_equal(keys$north, c(FALSE, TRUE))
  # all of them are moved to the events
  expect_true(all(c("species", "colony_sf", "north") %in% names(result)))
  expect_equal(names(show_meta(result)), "bird_id")
})

test_that("group_by_meta works when the metadata is an sf table", {
  # the geometry of the metadata has the name of the geometry of the events,
  # so it is renamed
  toy_tt <- create_toy_tt_sf_meta("geometry")
  expect_message(
    result <- group_by_meta(toy_tt, species),
    "so it has been renamed 'geometry.meta'"
  )
  expect_equal(dplyr::group_vars(result), "species")
  expect_equal(dplyr::group_size(result), c(24L, 6L))
  expect_s3_class(show_meta(result)$geometry.meta, "sfc")
  expect_equal(attr(result, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(result), sf::st_coordinates(toy_tt))
  # group by the geometry of the metadata
  expect_message(
    result <- group_by_meta(toy_tt, geometry.meta),
    "so it has been renamed 'geometry.meta'"
  )
  expect_equal(dplyr::n_groups(result), 2L)
  expect_s3_class(result$geometry.meta, "sfc")
  expect_equal(attr(result, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(result), sf::st_coordinates(toy_tt))

  # the geometry of the metadata has another name
  toy_tt <- create_toy_tt_sf_meta("colony_sf")
  expect_no_message(result <- group_by_meta(toy_tt, colony_sf))
  expect_equal(dplyr::n_groups(result), 2L)
  expect_s3_class(result$colony_sf, "sfc")
  expect_false(inherits(show_meta(result), "sf"))
  expect_equal(attr(result, "sf_column"), "geometry")
  expect_equal(sf::st_coordinates(result), sf::st_coordinates(toy_tt))
})

test_that("group_by_meta adds to or replaces groups as dplyr::group_by", {
  toy_tt <- dplyr::group_by(create_toy_tt(), bird_id)
  # .add
  result <- group_by_meta(toy_tt, species, .add = TRUE)
  expect_equal(dplyr::group_vars(result), c("bird_id", "species"))
  expect_equal(dplyr::n_groups(result), 2L)
  # the groups are replaced by default
  result <- group_by_meta(toy_tt, species)
  expect_equal(dplyr::group_vars(result), "species")
  # without variables, the object is ungrouped, unless .add = TRUE
  expect_equal(dplyr::group_vars(group_by_meta(toy_tt)), character(0))
  expect_equal(
    dplyr::group_vars(group_by_meta(toy_tt, .add = TRUE)),
    "bird_id"
  )

  # .drop is passed on, for factors with levels without events
  toy_tt <- create_toy_tt()
  show_meta(toy_tt)$species <- factor(
    show_meta(toy_tt)$species,
    levels = c("species_a", "species_b", "species_c")
  )
  expect_equal(dplyr::n_groups(group_by_meta(toy_tt, species)), 2L)
  result <- group_by_meta(toy_tt, species, .drop = FALSE)
  expect_equal(dplyr::n_groups(result), 3L)
  expect_equal(dplyr::group_size(result), c(24L, 6L, 0L))
})

test_that("group_by_meta groups by the track id without moving it", {
  toy_tt <- create_toy_tt()
  result <- group_by_meta(toy_tt, bird_id)
  expect_equal(dplyr::group_vars(result), "bird_id")
  expect_equal(dplyr::n_groups(result), 2L)
  expect_equal(show_meta(result), show_meta(toy_tt))
  expect_equal(names(result), names(toy_tt))
})

test_that("group_by_meta reuses a column already in the events", {
  # species is in both tables, with the same values
  toy_tt <- as_event_column(create_toy_tt(), species, .keep = TRUE)
  result <- group_by_meta(toy_tt, species)
  expect_equal(dplyr::group_vars(result), "species")
  expect_equal(dplyr::group_size(result), c(24L, 6L))
  # it is only removed from the metadata, rather than joined again
  expect_equal(names(result), names(toy_tt))
  expect_false("species" %in% names(show_meta(result)))
  # the same for an sfc column
  toy_tt <- as_event_column(create_toy_tt_geo(), colony_sf, .keep = TRUE)
  result <- group_by_meta(toy_tt, colony_sf)
  expect_equal(dplyr::n_groups(result), 2L)
  expect_equal(names(result), names(toy_tt))
  expect_false("colony_sf" %in% names(show_meta(result)))

  # a column of the events with different values gives an error
  toy_tt <- create_toy_tt()
  toy_tt$species <- "species_c"
  expect_error(
    group_by_meta(toy_tt, species),
    "already have column\\(s\\) 'species', with values that differ"
  )
  # including values of incompatible types
  toy_tt$species <- 1
  expect_error(
    group_by_meta(toy_tt, species),
    "already have column\\(s\\) 'species', with values that differ"
  )
})

test_that("group_by_meta points to dplyr::group_by for columns of the events", {
  toy_tt <- group_by_meta(create_toy_tt(), species)
  # species has been moved to the events
  expect_error(
    group_by_meta(toy_tt, species),
    "'species' are not in the metadata, but in the events"
  )
  # a column that is in neither table gives the error of dplyr
  expect_error(group_by_meta(toy_tt, not_a_column))
})

test_that("group_by_meta groups the home ranges of the hr_tt_* functions", {
  toy_tt <- sf::st_transform(create_toy_tt_geo(), 3857)
  # the same as moving the column to the events and grouping by it
  result <- hr_tt_mcp(group_by_meta(toy_tt, species), levels = 0.95)
  expected <- toy_tt |>
    as_event_column(species) |>
    dplyr::group_by(species) |>
    hr_tt_mcp(levels = 0.95)
  expect_equal(result, expected)
  expect_equal(result$species, c("species_a", "species_b"))

  # group by an sfc column, which is kept as an sfc column of the home ranges
  grouped_tt <- group_by_meta(toy_tt, colony_sf)
  for (result in list(
    hr_tt_mcp(grouped_tt, levels = 0.95),
    hr_tt_kde(grouped_tt, levels = 0.95),
    hr_tt_locoh(grouped_tt, n = 4, levels = 0.95)
  )) {
    expect_s3_class(result, "hr_tt_poly_tbl")
    expect_equal(nrow(result), 2L)
    expect_equal(names(result)[1:2], c("colony_sf", "method"))
    expect_s3_class(result$colony_sf, "sfc")
    expect_equal(sf::st_crs(result$colony_sf), sf::st_crs(4326))
    expect_equal(sf::st_coordinates(result$colony_sf)[, "Y"], c(10, 50))
    # the geometry of the home ranges is still the active one
    expect_equal(attr(result, "sf_column"), "geometry")
    expect_true(all(
      sf::st_geometry_type(result) %in% c("POLYGON", "MULTIPOLYGON")
    ))
    expect_true(sf::st_crs(result) == sf::st_crs(toy_tt))
  }
  # the UDs are named after the colonies, written as WKT
  kde <- hr_tt_kde(grouped_tt)
  expect_s3_class(kde$colony_sf, "sfc")
  expect_equal(names(kde$ud), c("POINT (0 10)", "POINT (0 50)"))
  # and so are the rows and columns of their overlaps
  expect_equal(
    rownames(hr_tt_ud_overlap(kde)),
    c("POINT (0 10)", "POINT (0 50)")
  )
  # the isopleths of the UDs keep the sfc column, and their own geometry
  iso <- hr_tt_ud_iso(kde, levels = 0.95)
  expect_s3_class(iso$colony_sf, "sfc")
  expect_equal(attr(iso, "sf_column"), "geometry")

  # with several grouping variables, one column per variable, with its type
  grouped_tt <- group_by_meta(toy_tt, species, colony_sf)
  result <- hr_tt_mcp(grouped_tt, levels = 0.95)
  expect_equal(names(result)[1:3], c("species", "colony_sf", "method"))
  expect_equal(result$species, c("species_a", "species_b"))
  expect_s3_class(result$colony_sf, "sfc")
  expect_equal(attr(result, "sf_column"), "geometry")
})
