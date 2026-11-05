# Implementation plan: Value Dashboard

This plan says **how** to build what `docs/spec.md` describes. Each section is written so a card
can point to it.

## 1. Stack

- **Language:** R 4.6.x. Environment managed with renv.
- **App framework:** shiny, with bslib for the page layout, tabs, and filter sidebar.
- **Charts:** ggplot2 line charts rendered with `renderPlot()`.
- **Table:** reactable for the sortable peer comparison table.
- **Storage:** DuckDB through DBI and duckdb.
- **Reading files:** readr for the clinical and finance CSVs, readxl for the lookup spreadsheet.
- **Data handling:** dplyr (1.1+), tidyr, lubridate, cli, rlang.
- **Development only:** testthat (3rd edition), shinytest2, styler, lintr, withr.

The setup card creates `renv.lock`, which pins the exact version of every package. That card
also copies the R and package versions into this section.

## 2. Project layout

The app is an R package named `valuedashboard`. A package layout gives testthat, lintr, and
`R CMD check` a standard structure with no extra setup.

| Path | Contents |
|------|----------|
| `DESCRIPTION`, `NAMESPACE` | Package metadata and exports |
| `renv.lock`, `renv/` | Pinned package versions |
| `.lintr` | lintr settings |
| `Makefile` | `format`, `lint`, `test`, `pre-pr` |
| `.Renviron.example` | Every env var the app reads, with fake values |
| `R/config.R` | Reads env vars; clear error when a required one is missing |
| `R/load_read.R` | Reads the three files and matches columns by name |
| `R/load_checks.R` | One function per failure rule, each returning a problems tibble |
| `R/load_report.R` | Writes `load-report.csv` into the drop folder |
| `R/load_drop.R` | `load_drop()`: read, check, then write all or nothing to DuckDB |
| `R/db.R` | Connect, create schema, read tables, `data_as_of()` |
| `R/metrics.R` | `monthly_metrics()` and `peer_table()` |
| `R/auth.R` | `current_user_email()` and `surgeon_for_email()` |
| `R/mod_filters.R` | Shiny module: date range, surgeon, procedure type |
| `R/mod_volume.R` | Shiny module: Volume tab |
| `R/mod_cost_value.R` | Shiny module: Cost / Value tab |
| `R/mod_outcomes.R` | Shiny module: Outcomes tab |
| `R/mod_peer.R` | Shiny module: Peer comparison tab |
| `R/app_ui.R`, `R/app_server.R` | Top-level UI and server |
| `R/run_app.R` | `run_app()`, the entry point |
| `inst/scripts/load_drop.R` | Command line wrapper for the monthly load |
| `inst/extdata/sample/` | Made-up test drops (section 8) |
| `tests/testthat/test-<name>.R` | One test file per `R/<name>.R` |
| `.github/workflows/ci.yaml` | CI (section 10) |

## 3. Data model

One DuckDB file, path set by `VD_DB_PATH`. The app opens it read-only. Only the load script
writes to it.

- `cases`, keyed on `case_id`: `case_id`, `surgeon_id`, `procedure_code`, `surgery_date`,
  `surgery_month`, `admission_date`, `discharge_date`, `los_days`, `died`, `cost`, `revenue`,
  `margin`, `drop_id`.
- `surgeons`, keyed on `surgeon_id`: `surgeon_id`, `name`, `sso_email`.
- `procedures`, keyed on `procedure_code`: `procedure_code`, `procedure_group`.
- `drops`, keyed on `drop_id`: `drop_id`, `folder`, `loaded_at`, `surgery_month`.

Column rules:

- `surgery_month` is the first day of the surgery date's month (a `Date`).
- `died` is logical. `los_days` is an integer. `cost`, `revenue`, `margin` are doubles.
- `margin` = `revenue - cost`, computed at load time.
- `surgeons` and `procedures` are replaced in full by each drop's lookup spreadsheet.
- `data_as_of()` returns `max(surgery_month)` from `cases`.

## 4. Loading

Entry point:

```r
load_drop(drop_dir, db_path)
```

Run monthly with `Rscript inst/scripts/load_drop.R <drop_dir>`. It returns the problems tibble
invisibly and exits with status 1 from the script when there are problems.

Steps:

1. Read the clinical file, finance file, and lookup spreadsheet. Match columns by name. The
   required column names for each file live in one named list in `R/load_read.R`.
2. Drop rows that are identical in every column, keeping one.
3. Run every check and collect all problems. Do not stop at the first one.
4. If there are any problems, write `load-report.csv` into `drop_dir` and load nothing.
5. Otherwise, write the drop inside one DuckDB transaction. If anything fails mid-write, roll
   back so the database is unchanged.

A drop fails when any of these is true (from the spec):

- A required column is missing.
- A case ID appears more than once with different values.
- A clinical case has no matching row in the finance file.
- A surgeon or procedure code is not in the lookup sheet.
- A surgery, admission, or discharge date can't be read, or discharge is before admission.

Not checked, by choice: text or blanks in number columns, negative values, a "died" flag that
isn't yes/no, and surgery dates outside the expected month.

The problems tibble, and the report, has one row per problem with columns `file`, `row`,
`column`, `rule`, `value`.

The real export column names are not known yet. Cards use placeholder names from the clinical
file list in the spec (`case_id`, `primary_surgeon`, `procedure`, `surgery_date`,
`admission_date`, `discharge_date`, `length_of_stay`, `died`; finance: `case_id`, `total_cost`,
`revenue`). Only the named list in `R/load_read.R` changes when the real names arrive.

## 5. Metrics

```r
monthly_metrics(cases, surgeon_id, date_range, procedure_groups)
peer_table(cases, date_range, procedure_groups)
```

- `cases` is a tibble shaped like the `cases` table joined to `procedures`.
- `date_range` is a length-2 `Date` vector, inclusive, filtered on `surgery_date`.
- `procedure_groups` is a character vector. An empty vector means all groups.
- `monthly_metrics()` returns one row per `surgery_month` for that surgeon.
- `peer_table()` returns one row per surgeon over the whole date range, ignoring the surgeon
  filter.

Both return columns `cases`, `avg_cost`, `avg_revenue`, `avg_margin`, `avg_los`,
`mortality_rate`, computed with `summarise(..., .by = ...)`:

- `cases` = `n()`
- `avg_cost` = `sum(cost) / n()`
- `avg_revenue` = `sum(revenue) / n()`
- `avg_margin` = `sum(margin) / n()`
- `avg_los` = `mean(los_days)`
- `mortality_rate` = `sum(died) / n()`, a proportion. The UI formats it as a percent.

Months with no cases are left out of the chart, not plotted as zero.

The spec's worked example is a required test: Dr. A, March, 4 cases gives cases 4, avg cost
17,500, avg revenue 19,000, avg margin 1,500, avg LOS 3.0, mortality 0.25.

## 6. Login and access

The host is not chosen yet, so the app reads the logged-in email from whichever source is
present, in this order:

1. `session$user` (set by Posit Connect).
2. The request header named in `VD_USER_HEADER` (set by a reverse proxy doing SSO).
3. `VD_DEV_USER_EMAIL`, for local development only. Ignored when `VD_ENV` is `production`.

```r
current_user_email(session)
surgeon_for_email(email, surgeons)
```

- The email match ignores case and surrounding spaces.
- No email, or an email not in `surgeons`: show a "You are not authorised" page and render
  nothing else.
- A match sets the Surgeon filter's default to that surgeon's ID.

## 7. Configuration

All settings come from env vars, kept locally in `.Renviron`, which is in `.gitignore`.
`.Renviron.example` is committed with fake values.

| Variable | Purpose |
|----------|---------|
| `VD_DB_PATH` | Path to the DuckDB file |
| `VD_DROP_DIR` | Shared folder where monthly drops land |
| `VD_USER_HEADER` | Request header holding the SSO email, e.g. `X-Forwarded-Email` |
| `VD_DEV_USER_EMAIL` | Email to log in as during local development |
| `VD_ENV` | `development` or `production` |

No passwords or keys are needed today, since there are no database connections.

## 8. Test data

All made up. Stored in `inst/extdata/sample/`.

- `good-drop/`: about 5 surgeons and 3 months. Includes the spec's worked example (Dr. A,
  March), a same-day case (LOS 0), a death, a case with a co-surgeon (credited only to the
  primary), and one exact-duplicate row.
- `bad-<rule>/`: one folder per failure rule, each with exactly one problem, plus `bad-many/`
  with several problems at once to test that every one is reported.
- A lookup spreadsheet with fake names and `@example.org` emails.

## 9. Formatter, linter, and tests

- Formatter: styler, tidyverse style.
- Linter: lintr defaults, line length 100. Any lint fails the `lint` target.
- Tests: testthat 3rd edition for functions, shinytest2 for each tab module.

Makefile targets:

| Target | Runs |
|--------|------|
| `format` | `styler::style_pkg()` |
| `lint` | `lintr::lint_package()`, exit 1 if any lints |
| `test` | `testthat::test_local()`, exit 1 on failure |
| `pre-pr` | `format`, then `lint`, then `test` |

## 10. CI

`.github/workflows/ci.yaml` runs on every pull request and every push to `main`. Two jobs, both
on `ubuntu-latest`:

- `lint`: `actions/checkout@v4`, `r-lib/actions/setup-r@v2`, `r-lib/actions/setup-renv@v2`,
  then `make lint`.
- `test`: same setup, then `make test`.

After CI runs once, add `lint` and `test` as required status checks in the "Protect main"
ruleset.

## 11. Deployment

Not decided. Whichever host is chosen must provide:

- R 4.6 and `renv::restore()`.
- Read access to the DuckDB file and write access for whoever runs the monthly load.
- An SSO layer that hands the app the user's email (Posit Connect, or a reverse proxy that sets
  `VD_USER_HEADER`).

Updating: merge to `main`, then redeploy. The deployment epic is written after the host is
chosen.

## 12. Build order

Each epic depends on the ones before it.

1. **Setup:** package skeleton, renv, `.lintr`, Makefile, CI, `.Renviron.example`, `.gitignore`
   entries.
2. **Test data:** good and bad sample drops.
3. **Loading:** read by name, each check, report, transactional DuckDB load, load script.
4. **Metrics:** `monthly_metrics()`, `peer_table()`, worked-example test.
5. **App shell:** config, auth, filters module, data-as-of display, tab layout.
6. **Screens:** Volume, Cost / Value, Outcomes, Peer comparison. One card per tab.
7. **Deployment:** after the host is chosen.

## 13. Open questions

- Exact column names and types in each export file.
- Which SSO provider and which host.
- Where on each tab the data-as-of date appears.
- What happens when a drop repeats an already-loaded month or case ID. Proposed default: fail
  the drop and list the repeats in the report. Confirm before writing the loading epic.
- In scope or future: risk adjustment, CSV/Excel export, peer lines on charts, small-number
  warnings, an admin role, a phone layout.
