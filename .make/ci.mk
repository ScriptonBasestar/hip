# .make/ci.mk - CI/CD pipeline targets

.PHONY: pre-release ci

pre-release: clean test lint build ## Prepare for release (clean, test, lint, build)
	@echo "✓ Ready for release"
	@ls -lh pkg/*.gem

ci: test lint ## Run CI checks (test and lint)
	@echo "✓ CI checks passed"
