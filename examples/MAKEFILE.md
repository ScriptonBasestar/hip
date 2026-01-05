# Makefile Integration with Hip

This guide shows how to integrate Hip commands into your project's Makefile for a streamlined development workflow.

## Quick Start

### 1. Install Hip

```bash
# See INSTALL.md for installation methods
gem install specific_install
gem specific_install https://github.com/ScriptonBasestar/hip.git
```

### 2. Create hip.yml

Create a `hip.yml` file in your project root. See [makefile-integration.yml](makefile-integration.yml) for a complete example.

```yaml
version: '9.1'

compose:
  files:
    - docker-compose.yml

interaction:
  rails:
    description: Run Rails commands
    service: app
    command: bundle exec rails

  rspec:
    description: Run tests
    service: app
    command: bundle exec rspec

provision:
  - hip compose up -d postgres redis
  - hip bundle install
  - hip rails db:setup
```

### 3. Add Makefile Targets

Copy the Hip usage examples from Hip's `Makefile.dev.mk` to your project's Makefile:

```makefile
# Hip Development Environment
.PHONY: hip-up hip-down hip-clean hip-console

hip-up: ## Start Hip Docker environment
	@hip compose up -d

hip-down: ## Stop Hip Docker environment
	@hip compose down

hip-console: ## Open Rails console
	@hip rails console

hip-provision: ## Run provisioning
	@hip provision
```

## Available Make Targets

Once integrated, you can use these commands:

| Command | Description |
|---------|-------------|
| `make hip-up` | Start Docker environment |
| `make hip-down` | Stop Docker environment |
| `make hip-clean` | Clean containers, volumes, networks |
| `make hip-console` | Open Rails console |
| `make hip-rails ARGS="db:migrate"` | Run Rails commands |
| `make hip-test` | Run tests |
| `make hip-logs` | Show container logs |
| `make hip-provision` | Run provisioning scripts |
| `make hip-dev` | Full dev cycle (down, clean, up, provision) |
| `make hip-restart` | Quick restart |

## Example Workflows

### Daily Development

```bash
# Start environment
make hip-up

# Open console
make hip-console

# Run migrations
make hip-rails ARGS="db:migrate"

# Run tests
make hip-test

# View logs
make hip-logs

# Stop environment
make hip-down
```

### Fresh Environment Setup

```bash
# Full clean and provision
make hip-dev
```

### Quick Restart After Changes

```bash
make hip-restart
```

## Advanced Integration

### Custom Targets

You can create custom targets that combine multiple Hip commands:

```makefile
# Custom: Deploy to staging
deploy-staging: hip-test
	@echo "Deploying to staging..."
	@hip rails db:migrate RAILS_ENV=staging
	@hip rails assets:precompile RAILS_ENV=staging
	@echo "✓ Deployed to staging"

# Custom: Run full test suite
test-all: hip-up
	@make hip-test ARGS="--tag ~slow"
	@make hip-test ARGS="--tag slow"
```

### Environment-Specific Targets

```makefile
# Development environment
dev-env:
	@COMPOSE_EXT=development make hip-up

# Test environment
test-env:
	@COMPOSE_EXT=test make hip-up
```

## Troubleshooting

### Hip command not found

```bash
# Check if hip is installed
hip --version

# If not, install it
gem install specific_install
gem specific_install https://github.com/ScriptonBasestar/hip.git
```

### hip.yml not found

Make sure `hip.yml` exists in your project root or current directory. Hip searches up the directory tree for the config file.

### Docker commands fail

Ensure Docker is running:

```bash
docker ps
```

### Rails commands fail

Check that your service is defined in `hip.yml`:

```yaml
interaction:
  rails:
    service: app  # Make sure this service exists in docker-compose.yml
    command: bundle exec rails
```

## Complete Example

See [makefile-integration.yml](makefile-integration.yml) for a complete hip.yml example that works with all Makefile targets.

## References

- [Hip README](../README.md) - Main documentation
- [Hip Examples](README.md) - All configuration examples
- [Hip Installation](../INSTALL.md) - Installation guide
- [Hip Development Makefile](../Makefile.dev.mk) - Source of example targets
