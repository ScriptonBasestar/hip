# .make/install.mk - Installation and bundling targets

.PHONY: install reinstall bundle bundle-update uninstall

install: build ## Build and install hip gem locally
	@echo "Installing hip..."
	@bundle exec rake install:local

reinstall: clean build install ## Clean, build, and reinstall hip gem (quick development cycle)
	@echo "✓ Hip reinstalled successfully"
	@hip --version

bundle: ## Install dependencies
	@echo "Installing dependencies..."
	@bundle install

bundle-update: ## Update dependencies
	@echo "Updating dependencies..."
	@bundle update

uninstall: ## Uninstall hip gem
	@echo "Uninstalling hip..."
	@gem uninstall hip -x || echo "Hip not installed"
