sample_cases <- function() {
  tibble::tribble(
    ~case_id, ~surgeon_id, ~surgeon_name, ~procedure_code, ~procedure_group,
    ~surgery_date, ~surgery_month, ~los_days, ~died, ~cost, ~revenue, ~margin,
    "c1", "s1", "Dr. A", "P1", "g1", as.Date("2026-03-02"), as.Date("2026-03-01"),
    0L, FALSE, 10000, 12000, 2000,
    "c2", "s1", "Dr. A", "P1", "g1", as.Date("2026-03-10"), as.Date("2026-03-01"),
    3L, FALSE, 20000, 18000, -2000,
    "c3", "s1", "Dr. A", "P2", "g2", as.Date("2026-03-20"), as.Date("2026-03-01"),
    2L, FALSE, 15000, 16000, 1000,
    "c4", "s1", "Dr. A", "P2", "g2", as.Date("2026-03-31"), as.Date("2026-03-01"),
    7L, TRUE, 25000, 30000, 5000,
    "c5", "s2", "Dr. B", "P1", "g1", as.Date("2026-03-15"), as.Date("2026-03-01"),
    1L, FALSE, 5000, 6000, 1000,
    "c6", "s1", "Dr. A", "P1", "g1", as.Date("2026-04-05"), as.Date("2026-04-01"),
    4L, FALSE, 9000, 9500, 500
  )
}

metric_columns <- c(
  "surgery_month",
  "cases",
  "avg_cost",
  "avg_revenue",
  "avg_margin",
  "avg_los",
  "mortality_rate"
)

test_that("monthly_metrics", {
  # given
  cases <- sample_cases()
  march <- as.Date(c("2026-03-01", "2026-03-31"))

  # when
  worked <- monthly_metrics(cases, "s1", march)
  none <- monthly_metrics(cases, "s9", march)

  # then
  expect_equal(nrow(worked), 1)
  expect_equal(worked$surgery_month, as.Date("2026-03-01"))
  expect_equal(worked$cases, 4)
  expect_equal(worked$avg_cost, 17500)
  expect_equal(worked$avg_revenue, 19000)
  expect_equal(worked$avg_margin, 1500)
  expect_equal(worked$avg_los, 3)
  expect_equal(worked$mortality_rate, 0.25)
  expect_equal(nrow(none), 0)
  expect_named(none, metric_columns)
})

test_that("filter_cases", {
  # given
  cases <- sample_cases()
  full_range <- as.Date(c("2026-03-01", "2026-04-30"))
  ranges <- list(
    c("2026-03-02", "2026-03-31", "c1,c2,c3,c4,c5"),
    c("2026-03-03", "2026-03-30", "c2,c3,c5"),
    c("2026-03-31", "2026-04-05", "c4,c6"),
    c("2026-05-01", "2026-05-31", "")
  )
  bad_ranges <- list(
    as.Date(c("2026-04-01", "2026-03-01")),
    as.Date("2026-03-01"),
    c("2026-03-01", "2026-04-01"),
    as.Date(c("2026-03-01", NA))
  )

  # when
  kept <- vapply(
    ranges,
    \(r) paste(filter_cases(cases, as.Date(r[1:2]))$case_id, collapse = ","),
    character(1)
  )
  all_groups <- filter_cases(cases, full_range)
  one_group <- filter_cases(cases, full_range, "g2")

  # then
  expect_equal(kept, vapply(ranges, \(r) r[3], character(1)))
  expect_equal(nrow(all_groups), 6)
  expect_equal(one_group$case_id, c("c3", "c4"))
  for (bad in bad_ranges) {
    expect_error(filter_cases(cases, bad), class = "vd_bad_date_range")
  }
})

test_that("summarise_cases", {
  # given
  cases <- sample_cases()

  # when
  overall <- summarise_cases(cases)
  by_surgeon <- summarise_cases(cases, .by = surgeon_id)

  # then
  expect_equal(nrow(overall), 1)
  expect_equal(overall$cases, 6)
  expect_equal(overall$avg_cost, 14000)
  expect_equal(nrow(by_surgeon), 2)
})
