# .make/status.mk - Status and information targets

.PHONY: status

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
