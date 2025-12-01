# Migration Guide

This guide helps you update your `hip.yml` configuration when upgrading Hip versions.

---

## v9.1.0: Provision Workflow Separation

**Release Date**: 2025-12-01

### What Changed

The `provision` command behavior has been **clarified** to focus on initialization tasks only. Previously, many users included container management (`docker compose up/down`) in provision scripts, which caused confusion about when to use `provision` vs `up`.

**Old Behavior** (Unclear):
```yaml
provision:
  default:
    - hip compose down --volumes  # Container management
    - hip compose up -d db        # Container management
    - hip bundle install          # Initialization
    - hip rails db:create         # Initialization
```

**New Behavior** (Clear):
```yaml
provision:
  default:
    - hip bundle install          # Initialization only
    - hip rails db:create
    - hip rails db:migrate
    - hip rails db:seed
```

### Why This Change?

**Problem**: Users were confused about the difference between:
- `hip up` - "Does this run provision too?"
- `hip provision` - "Does this start containers?"

**Solution**: Clear separation of concerns:
- `hip up` → Start containers only
- `hip provision` → Initialize application (requires containers to be running)

### Migration Steps

#### Step 1: Review Your provision Section

Check your `hip.yml` for these patterns:

```bash
# Find docker compose commands in provision
grep -A 10 "^provision:" hip.yml | grep "compose.*\(up\|down\)"
```

#### Step 2: Remove Container Management

**Before**:
```yaml
provision:
  default:
    - hip compose down --volumes
    - hip compose up -d postgres redis
    - hip bundle install
    - hip rails db:create
    - hip rails db:migrate
```

**After**:
```yaml
provision:
  # Note: Run 'hip up -d' first to start containers
  default:
    - hip bundle install
    - hip rails db:create
    - hip rails db:migrate
```

#### Step 3: Update Your Workflow

**Old Workflow**:
```bash
hip provision  # Did everything: down → up → initialize
```

**New Workflow**:
```bash
hip up -d      # Start containers in background
hip provision  # Initialize application
```

#### Step 4: Update Documentation

If you have project-specific documentation, update commands:

**Before**:
```markdown
## Setup
Run `hip provision` to set up the project.
```

**After**:
```markdown
## Setup
1. Start containers: `hip up -d`
2. Initialize application: `hip provision`
```

### Examples by Language/Framework

#### Ruby on Rails

**Before**:
```yaml
provision:
  default:
    - hip compose down --volumes
    - hip compose up -d postgres redis
    - hip bundle install
    - hip rails db:create
    - hip rails db:migrate
    - hip rails db:seed
```

**After**:
```yaml
provision:
  # Run 'hip up -d' first
  default:
    - hip bundle install
    - hip rails db:create
    - hip rails db:migrate
    - hip rails db:seed
```

#### Node.js

**Before**:
```yaml
provision:
  default:
    - hip compose down --volumes
    - hip compose up -d mongo redis
    - hip npm install
    - hip npm run build
```

**After**:
```yaml
provision:
  # Run 'hip up -d' first
  default:
    - hip npm install
    - hip npm run build
```

#### Go

**Before**:
```yaml
provision:
  default:
    - hip compose up -d postgres
    - hip go mod download
    - hip go run cmd/migrate/main.go
```

**After**:
```yaml
provision:
  # Run 'hip up -d' first
  default:
    - hip go mod download
    - hip go run cmd/migrate/main.go
```

### Special Cases

#### Multiple Profiles

If you have multiple provision profiles, update each one:

```yaml
provision:
  # Development setup
  default:
    - hip bundle install
    - hip rails db:migrate

  # Full reset (still needs container management)
  reset:
    - hip compose down --volumes  # OK: Explicit cleanup
    - hip compose up -d
    - hip bundle install
    - hip rails db:setup

  # CI setup
  ci:
    - hip npm ci
    - hip npm run test
```

**Note**: The `reset` profile can still include container management if it's an explicit cleanup/restart workflow.

#### Wait for Services

If your provision needs to wait for services:

**Before**:
```yaml
provision:
  default:
    - hip compose up -d postgres
    - sleep 5  # Wait for postgres
    - hip rails db:create
```

**After**:
```yaml
provision:
  # Run 'hip up -d' first and wait for readiness
  default:
    - sleep 5  # Wait for services to be ready
    - hip rails db:create
```

Or better, use health checks in `docker-compose.yml`:
```yaml
services:
  db:
    image: postgres:15
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user"]
      interval: 5s
      timeout: 5s
      retries: 5
```

### Backward Compatibility

**Is this a breaking change?**

**No**. The `provision` command still works the same way - it executes the commands you define. The change is **conceptual clarification** with updated examples.

**Your existing hip.yml will continue to work**, but we recommend updating to the new pattern for:
- ✅ Clearer intent
- ✅ Better separation of concerns
- ✅ Consistent with documentation and examples

### Verification

After migration, verify your setup works:

```bash
# Clean start
hip down
hip up -d
hip provision

# Verify services are running
docker compose ps

# Verify initialization succeeded
hip rails console  # or your app-specific command
```

### Rollback

If you need to revert temporarily:

```bash
# Your old provision will still work as-is
hip provision  # Still executes all commands you defined
```

To rollback Hip version:
```bash
# If using Bundler
bundle update hip --conservative

# If using gem
gem uninstall hip
gem install hip -v 9.0.0
```

### Getting Help

If you encounter issues during migration:

1. **Check Examples**: See updated examples in `examples/` directory
2. **Read Documentation**: See `README.md` for workflow explanation
3. **Ask Questions**: Open an issue on GitHub

### FAQ

**Q: Do I need to update my hip.yml immediately?**

A: No, your existing configuration will continue to work. Update when convenient.

**Q: Can I still use `docker compose up` in provision?**

A: Yes, but it's not recommended. The new pattern provides clearer separation.

**Q: What if my provision needs to restart containers?**

A: Create a specific profile for that:
```yaml
provision:
  default:
    - hip bundle install

  restart:
    - hip compose restart
    - hip bundle install
```

**Q: How do I update all examples at once?**

A: Use this script:
```bash
# Remove docker compose up/down from provision sections
find . -name "hip.yml" -exec sed -i '/provision:/,/^[^ ]/{
  /compose.*\(up\|down\)/d
}' {} \;
```

---

**Last Updated**: 2025-12-01
**Applies To**: Hip v9.1.0 and later
