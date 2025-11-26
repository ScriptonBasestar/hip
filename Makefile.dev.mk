# Makefile.dev.mk - Development workflow for Hip gem
# Usage: make -f Makefile.dev.mk <target>

.PHONY: help reinstall install build clean test lint format console version

# Default target
help: ## Show this help message
	@echo "Hip Development Makefile"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile.dev.mk | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

reinstall: clean build install ## Clean, build, and reinstall hip gem (quick development cycle)
	@echo "✓ Hip reinstalled successfully"
	@hip --version

install: build ## Build and install hip gem locally
	@echo "Installing hip..."
	@bundle exec rake install:local

build: ## Build hip gem
	@echo "Building hip gem..."
	@bundle exec rake build

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@bundle exec rake clean
	@rm -f pkg/*.gem

clobber: ## Remove all generated files
	@echo "Removing all generated files..."
	@bundle exec rake clobber

test: ## Run all tests
	@echo "Running tests..."
	@bundle exec rspec

test-fast: ## Run tests without coverage
	@echo "Running fast tests..."
	@NO_COVERAGE=1 bundle exec rspec

lint: ## Run rubocop linter
	@echo "Running rubocop..."
	@bundle exec rubocop

format: ## Auto-fix rubocop offenses
	@echo "Auto-fixing rubocop offenses..."
	@bundle exec rubocop -a

console: ## Open pry console with hip loaded
	@echo "Opening pry console..."
	@bundle exec pry -r ./lib/hip

version: ## Show hip version
	@hip --version 2>/dev/null || echo "Hip not installed. Run 'make -f Makefile.dev.mk install' first."

bundle: ## Install dependencies
	@echo "Installing dependencies..."
	@bundle install

bundle-update: ## Update dependencies
	@echo "Updating dependencies..."
	@bundle update

check: test lint ## Run tests and linter

# Quick development workflow
dev: reinstall test ## Reinstall and run tests (full dev cycle)
	@echo "✓ Development cycle complete"

# Release preparation
pre-release: clean test lint build ## Prepare for release (clean, test, lint, build)
	@echo "✓ Ready for release"
	@ls -lh pkg/*.gem

# Show current status
status: ## Show current development status
	@echo "=== Hip Development Status ==="
	@echo ""
	@echo "Installed version:"
	@hip --version 2>/dev/null || echo "  Not installed"
	@echo ""
	@echo "Built gems:"
	@ls -1 pkg/*.gem 2>/dev/null || echo "  No gems built"
	@echo ""
	@echo "Git status:"
	@git status --short
	@echo ""
	@echo "Recent commits:"
	@git log --oneline -3

# Uninstall hip
uninstall: ## Uninstall hip gem
	@echo "Uninstalling hip..."
	@gem uninstall hip -x || echo "Hip not installed"

# Full reset (uninstall + clean)
reset: uninstall clean ## Uninstall and clean everything
	@echo "✓ Full reset complete"
