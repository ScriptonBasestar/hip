# .make/hip-examples.mk - Hip usage examples for projects using Hip
# These targets demonstrate how to use Hip in your application projects
# Requires: hip.yml configuration file in your project root

.PHONY: hip-up hip-down hip-clean hip-console hip-rails hip-logs hip-provision hip-test hip-dev hip-restart

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

hip-dev: hip-down hip-clean hip-up hip-provision ## Full Hip dev cycle (down, clean, up, provision)
	@echo "✓ Hip development environment ready"

hip-restart: hip-down hip-up ## Quick restart Hip environment
	@echo "✓ Hip environment restarted"
