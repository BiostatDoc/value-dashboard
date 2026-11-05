.PHONY: format lint test pre-pr

format:
	Rscript -e "styler::style_pkg()"

lint:
	Rscript tools/lint.R

test:
	Rscript -e "testthat::test_local(stop_on_failure = TRUE)"

pre-pr: format lint test
