pkgload::load_all(quiet = TRUE)
lints <- lintr::lint_package()
print(lints)
quit(status = as.integer(length(lints) > 0))
