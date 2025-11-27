# .make/lint.mk - Lint and format targets

.PHONY: lint format

lint: ## Run rubocop linter
	@echo "Running rubocop..."
	@bundle exec rubocop

format: ## Auto-fix rubocop offenses
	@echo "Auto-fixing rubocop offenses..."
	@bundle exec rubocop -a
