# .make/build.mk - Build targets

.PHONY: build clean clobber

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
