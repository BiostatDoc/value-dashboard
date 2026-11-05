config_vars <- c(
  "VD_DB_PATH",
  "VD_DROP_DIR",
  "VD_USER_HEADER",
  "VD_DEV_USER_EMAIL",
  "VD_ENV"
)

local_config_env <- function(..., .local_envir = parent.frame()) {
  cleared <- stats::setNames(rep(list(NA_character_), length(config_vars)), config_vars)
  withr::local_envvar(cleared, .local_envir = .local_envir)
  withr::local_envvar(list(...), .local_envir = .local_envir)
}

test_that("vd_config returns settings from the environment", {
  cases <- list(
    all_set = list(
      env = list(
        VD_DB_PATH = "data/test.duckdb",
        VD_DROP_DIR = "drops",
        VD_USER_HEADER = "X-Forwarded-Email",
        VD_DEV_USER_EMAIL = "dr.a@example.org",
        VD_ENV = "production"
      ),
      expected = list(
        db_path = "data/test.duckdb",
        drop_dir = "drops",
        user_header = "X-Forwarded-Email",
        dev_user_email = "dr.a@example.org",
        env = "production"
      )
    ),
    only_db_path = list(
      env = list(VD_DB_PATH = "data/test.duckdb"),
      expected = list(
        db_path = "data/test.duckdb",
        drop_dir = NA_character_,
        user_header = NA_character_,
        dev_user_email = NA_character_,
        env = "development"
      )
    ),
    empty_optionals = list(
      env = list(
        VD_DB_PATH = "data/test.duckdb",
        VD_DROP_DIR = "",
        VD_USER_HEADER = "",
        VD_DEV_USER_EMAIL = "",
        VD_ENV = ""
      ),
      expected = list(
        db_path = "data/test.duckdb",
        drop_dir = NA_character_,
        user_header = NA_character_,
        dev_user_email = NA_character_,
        env = "development"
      )
    )
  )

  for (case in cases) {
    do.call(local_config_env, case$env)
    expect_identical(vd_config(), case$expected)
  }
})

test_that("vd_config aborts on invalid settings", {
  cases <- list(
    empty_db_path = list(VD_DB_PATH = ""),
    missing_db_path = list(VD_ENV = "development"),
    unknown_env = list(VD_DB_PATH = "data/test.duckdb", VD_ENV = "staging")
  )

  for (env in cases) {
    do.call(local_config_env, env)
    expect_error(vd_config(), class = "vd_config_error")
  }
})
