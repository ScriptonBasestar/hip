# Hip Configuration for Discourse Plugin Development

This guide explains how to set up Hip for Discourse plugin development.

## Quick Start

### 1. Copy hip.yml to Your Project

```bash
# In your gorisa-plugins or discourse project directory
cp /path/to/hip/examples/discourse-plugin-dev.yml hip.yml
```

Or create it manually (see below).

### 2. Verify docker-compose.yml

Make sure your `docker-compose.yml` has a `discourse` service (or similar):

```yaml
services:
  discourse:
    image: discourse/discourse_dev:latest
    # or build from local
    volumes:
      - .:/src
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:14
    environment:
      POSTGRES_USER: discourse
      POSTGRES_DB: discourse_development

  redis:
    image: redis:7
```

**Note**: If your service name is different (e.g., `app`, `web`), update `service: discourse` in hip.yml to match.

### 3. Start Environment

```bash
# First time setup
hip provision

# Or manually
hip compose up -d
hip bundle install
hip rails db:create db:migrate
```

## Available Commands

### Rails Commands
```bash
hip rails console          # Open Rails console
hip rails server           # Start Rails server
hip rails db:migrate       # Run migrations
hip rails db:seed          # Seed database
hip rails db:reset         # Reset database
```

### Bundle Commands
```bash
hip bundle install         # Install gems
hip bundle update          # Update gems
```

### Testing
```bash
hip rspec                  # Run all tests
hip rspec spec/models/     # Run specific tests
hip plugin test            # Run plugin tests
```

### Shell Access
```bash
hip bash                   # Open bash shell
hip shell                  # Same as bash
hip psql                   # PostgreSQL console
hip redis-cli              # Redis CLI
```

### Discourse Specific
```bash
hip discourse admin:create     # Create admin user
hip discourse precompile       # Precompile assets
hip plugin install            # Install plugin dependencies
```

## Directory Structure

### Option A: Discourse with Plugins
```
gorisa-web-discourse/
├── hip.yml
├── docker-compose.yml
├── discourse/              # Discourse core
│   └── ...
└── plugins/
    └── gorisa-plugins/     # Your plugin
        └── ...
```

### Option B: Plugin Development Only
```
gorisa-plugins/
├── hip.yml
├── docker-compose.yml      # Minimal compose with Discourse
└── plugin.rb
```

## Example hip.yml

Minimal version for quick setup:

```yaml
version: '8.2'

compose:
  files:
    - docker-compose.yml

interaction:
  rails:
    description: Run Rails commands
    service: discourse  # Change if your service name is different
    command: bundle exec rails

  bundle:
    description: Run Bundler
    service: discourse
    command: bundle

  bash:
    description: Open shell
    service: discourse
    command: bash

provision:
  - hip compose up -d postgres redis
  - hip bundle install
  - hip rails db:create db:migrate
```

## Common Workflows

### Daily Development

```bash
# Start environment
hip compose up -d

# Open console to test
hip rails console

# Run migrations after changes
hip rails db:migrate

# Restart Rails (if needed)
hip compose restart discourse

# View logs
hip compose logs -f discourse
```

### Plugin Development

```bash
# Open shell in Discourse container
hip bash

# Inside container, test your plugin
cd plugins/gorisa-plugins
bundle exec rspec

# Or use hip command
hip plugin test
```

### Database Management

```bash
# Create fresh database
hip rails db:create

# Run migrations
hip rails db:migrate

# Seed data
hip rails db:seed

# Reset everything
hip rails db:reset
```

## Troubleshooting

### "Could not find hip.yml"

Make sure hip.yml is in your project root:

```bash
# Check current directory
pwd

# Create hip.yml
cp examples/discourse-plugin-dev.yml hip.yml
```

### "Service 'discourse' not found"

Your docker-compose.yml might use a different service name. Check:

```bash
grep 'services:' -A 20 docker-compose.yml
```

Then update `service: discourse` in hip.yml to match (e.g., `service: app`).

### "Connection refused to postgres"

Wait a bit longer for services to start:

```bash
hip compose up -d postgres redis
sleep 10
hip rails db:create
```

### Gems not installing

```bash
# Clear bundle cache
hip compose down -v
hip compose up -d
hip bundle install
```

## Advanced Configuration

### Using Different Compose Files

```yaml
compose:
  files:
    - docker-compose.yml
    - docker-compose.development.yml
  project_name: gorisa-discourse
```

### Environment Variables

```yaml
environment:
  RAILS_ENV: development
  DISCOURSE_HOSTNAME: localhost:3000
  DISCOURSE_DEVELOPER_EMAILS: admin@example.com
```

### Custom Plugin Commands

```yaml
interaction:
  plugin:
    description: Plugin commands
    service: discourse
    command: bundle exec rails
    subcommands:
      lint:
        description: Lint plugin code
        command: bundle exec rubocop plugins/gorisa-plugins

      test:fast:
        description: Fast plugin tests
        environment:
          RAILS_ENV: test
        command: bundle exec rspec plugins/gorisa-plugins --tag ~slow
```

## References

- [Discourse Development Guide](https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/102009)
- [Hip Documentation](../README.md)
- [Hip Examples](README.md)
- [discourse-plugin-dev.yml](discourse-plugin-dev.yml) - Full example
