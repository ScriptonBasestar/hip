# .make/dev.mk - Development workflow targets

.PHONY: dev console version

dev: reinstall test ## Reinstall and run tests (full dev cycle)
	@echo "✓ Development cycle complete"

console: ## Open pry console with hip loaded
	@echo "Opening pry console..."
	@bundle exec pry -r ./lib/hip

version: ## Show hip version
	@hip --version 2>/dev/null || echo "Hip not installed. Run 'make install' first."
