# .make/test.mk - Test targets

.PHONY: test test-fast check

test: ## Run all tests
	@echo "Running tests..."
	@bundle exec rspec

test-fast: ## Run tests without coverage
	@echo "Running fast tests..."
	@NO_COVERAGE=1 bundle exec rspec

check: test lint ## Run tests and linter
