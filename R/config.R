valid_envs <- c("development", "production")

read_env <- function(name, default = NA_character_) {
  value <- Sys.getenv(name, unset = "")
  if (identical(value, "")) default else value
}

#' Read app settings from environment variables
#'
#' @return A list with `db_path`, `drop_dir`, `user_header`, `dev_user_email`
#'   and `env`.
#' @noRd
vd_config <- function() {
  db_path <- read_env("VD_DB_PATH")
  if (is.na(db_path)) {
    cli::cli_abort(
      "{.envvar VD_DB_PATH} must be set.",
      class = "vd_config_error"
    )
  }

  env <- read_env("VD_ENV", default = "development")
  if (!env %in% valid_envs) {
    cli::cli_abort(
      "{.envvar VD_ENV} must be one of {.val {valid_envs}}, not {.val {env}}.",
      class = "vd_config_error"
    )
  }

  list(
    db_path = db_path,
    drop_dir = read_env("VD_DROP_DIR"),
    user_header = read_env("VD_USER_HEADER"),
    dev_user_email = read_env("VD_DEV_USER_EMAIL"),
    env = env
  )
}
