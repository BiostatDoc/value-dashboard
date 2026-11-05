is_valid_date_range <- function(date_range) {
  inherits(date_range, "Date") &&
    length(date_range) == 2 &&
    !anyNA(date_range) &&
    date_range[1] <= date_range[2]
}

filter_cases <- function(cases, date_range, procedure_groups = character()) {
  if (!is_valid_date_range(date_range)) {
    cli::cli_abort(
      "{.arg date_range} must be two Dates with the start on or before the end.",
      class = "vd_bad_date_range"
    )
  }
  in_range <- cases$surgery_date >= date_range[1] & cases$surgery_date <= date_range[2]
  in_groups <- length(procedure_groups) == 0 | cases$procedure_group %in% procedure_groups
  cases[in_range & in_groups, ]
}

summarise_cases <- function(cases, .by = NULL) {
  dplyr::summarise(
    cases,
    cases = dplyr::n(),
    avg_cost = sum(.data$cost) / dplyr::n(),
    avg_revenue = sum(.data$revenue) / dplyr::n(),
    avg_margin = sum(.data$margin) / dplyr::n(),
    avg_los = mean(.data$los_days),
    mortality_rate = sum(.data$died) / dplyr::n(),
    .by = {{ .by }}
  )
}

monthly_metrics <- function(cases, surgeon_id, date_range, procedure_groups = character()) {
  cases |>
    filter_cases(date_range, procedure_groups) |>
    dplyr::filter(.data$surgeon_id == .env$surgeon_id) |>
    summarise_cases(.by = dplyr::all_of("surgery_month")) |>
    dplyr::arrange(.data$surgery_month)
}
