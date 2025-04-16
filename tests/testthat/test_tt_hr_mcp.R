test_that("tt_hr_mcp works with multiple tracks", {
  # load a simple dataset originally from adehabitat
  boar_mt <- readRDS("testdata/wildboar_mt.rds")
  # error if not grouped
  expect_error(
    boar_mcp <- tt_hr_mcp(boar_mt, levels = c(0.50, 0.95, 1)),
    "x must be a grouped move2 object")
  # group by name
  boar_mt <- boar_mt %>%
    dplyr::group_by(Name)
  boar_mcp <- tt_hr_mcp(boar_mt, levels = c(0.50, 0.95, 1))
  # expect 12 rows
  expect_equal(nrow(boar_mcp), 12)
  # expect this is an sf object
  expect_true(inherits(boar_mcp, "sf"))
  # now group by name and age
  boar_mt <- boar_mt %>%
    dplyr::group_by(Name, Age)
  boar_mcp_2var <- tt_hr_mcp(boar_mt, levels = c(0.50, 0.95, 1))
  # expect 12 rows
  expect_equal(nrow(boar_mcp), 12) # TODO change the ages to give some combinations

  # simple plotting example to check the geometry
  #  ggplot(boar_mcp) +
  #    geom_sf(aes(fill=group_id), alpha = 0.7)
})
