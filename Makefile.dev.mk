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

# ==================================================================================================
# Hip Usage Examples - For projects using Hip (converted from DIP)
# ==================================================================================================
# These targets demonstrate how to use Hip in your application projects
# Requires: hip.yml configuration file in your project root
# ==================================================================================================

.PHONY: hip-up hip-down hip-clean hip-console hip-rails hip-logs hip-provision hip-test

hip-up: ## Start Hip Docker environment (requires hip.yml)
	@echo "Starting Hip development environment..."
	@hip compose up -d
	@echo "✓ Hip environment started"

hip-down: ## Stop Hip Docker environment
	@echo "Stopping Hip environment..."
	@hip compose down
	@echo "✓ Hip environment stopped"

hip-clean: ## Clean Hip environment (containers, volumes, networks)
	@echo "Cleaning Hip environment..."
	@hip compose down -v
	@docker container prune -f 2>/dev/null || true
	@docker volume prune -f 2>/dev/null || true
	@docker network prune -f 2>/dev/null || true
	@echo "✓ Hip environment cleaned"

hip-console: ## Open Rails console via Hip (requires hip.yml with rails interaction)
	@hip rails console

hip-rails: ## Run Rails commands via Hip (usage: make hip-rails ARGS="db:migrate")
	@hip rails $(ARGS)

hip-logs: ## Show Hip container logs
	@hip compose logs -f

hip-provision: ## Run Hip provisioning scripts (defined in hip.yml)
	@hip provision

hip-test: ## Run tests via Hip (requires hip.yml with test interaction)
	@hip rspec $(ARGS)

# Example: Full Hip development cycle
hip-dev: hip-down hip-clean hip-up hip-provision ## Full Hip dev cycle (down, clean, up, provision)
	@echo "✓ Hip development environment ready"

# Example: Quick restart
hip-restart: hip-down hip-up ## Quick restart Hip environment
	@echo "✓ Hip environment restarted"
