# .make/release.mk - Release and reset targets

.PHONY: reset

reset: uninstall clean ## Uninstall and clean everything
	@echo "✓ Full reset complete"
