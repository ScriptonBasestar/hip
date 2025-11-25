# CLAUDE.md - Hip CLI for LLMs

**Quick Reference:** See `CONTEXT_MAP.md` for file navigation by task type.

---

## TL;DR

Hip is a Ruby CLI gem that wraps Docker Compose/Kubernetes commands with simple shortcuts defined in `hip.yml`.

**Core Flow:** `hip command` → CLI routing → InteractionTree lookup → Runner execution (Docker/Kubectl/Local)

**Entry Points:**
- `exe/hip` (22 lines) → `lib/hip.rb` (47 lines) → `lib/hip/cli.rb` (156 lines)

**Key Files:**
- `lib/hip/config.rb` - hip.yml parsing, modules, validation
- `lib/hip/commands/run.rb` - Command dispatch to runners
- `lib/hip/commands/runners/` - Execution strategies (Docker/Kubectl/Local)
- `schema.json` - hip.yml validation rules

**Runner Selection:**
```
command[:runner] → explicit runner
command[:service] → DockerComposeRunner
command[:pod] → KubectlRunner
else → LocalRunner
```

---

## Development Commands

```bash
# Setup
bundle install                # Install dependencies

# Testing
bundle exec rspec             # Run all tests (90% coverage required)
bundle exec rubocop           # Lint (must pass)
bundle exec rubocop -a        # Auto-fix

# Build
rake build                    # Build gem
rake install:local            # Install locally

# Using Hip on itself
hip shell                     # Open container bash
hip rspec <args>             # Run specs in container
hip rubocop <args>           # Lint in container
```

---

## Architecture

### Components

| Component | File | Purpose |
|-----------|------|---------|
| CLI Entry | `lib/hip/cli.rb` | Thor routing, TOP_LEVEL_COMMANDS dispatch |
| Config | `lib/hip/config.rb` | hip.yml parsing, modules, schema validation |
| Command Dispatch | `lib/hip/commands/run.rb` | InteractionTree lookup, runner selection |
| Runners | `lib/hip/commands/runners/` | Docker/Kubectl/Local execution strategies |
| Environment | `lib/hip/environment.rb` | Variable interpolation ($VAR, ${VAR}) |
| Command Tree | `lib/hip/interaction_tree.rb` | Parse hip.yml interaction: hierarchy |

### Configuration System

**Hierarchy:**
1. Base: `hip.yml` (discovered by walking up directory tree)
2. Modules: `.hip/*.yml` (merged into base)
3. Overrides: `hip.override.yml` (local, git-ignored)

**Interaction Mapping:**
- `service:` key → DockerComposeRunner
- `pod:` key → KubectlRunner
- Neither → LocalRunner

### Design Patterns

- **Command Pattern**: Each CLI command = separate class
- **Strategy Pattern**: Runners = execution strategies
- **Template Method**: `Hip::Command` base class with shared logic
- **Configuration as Code**: hip.yml defines declarative commands

---

## Extending Hip

### Add Command

1. Create `lib/hip/commands/my_command.rb` inheriting `Hip::Command`
2. Register in `lib/hip/cli.rb`:
   ```ruby
   desc "my-cmd", "Description"
   def my_cmd(*argv)
     require_relative "commands/my_command"
     Hip::Commands::MyCommand.new(*argv).execute
   end
   ```
3. Add tests: `spec/lib/hip/commands/my_command_spec.rb`

### Add Runner

1. Create `lib/hip/commands/runners/my_runner.rb` inheriting `Base`
2. Implement `#execute` method
3. Update `lib/hip/commands/run.rb` `lookup_runner` logic
4. Add tests with FakeFS fixtures

### Modify hip.yml Schema

1. Edit `schema.json` with new properties
2. Update `lib/hip/config.rb` if new top-level key
3. Add validation tests
4. Create example in `examples/`

---

## Testing

Uses **FakeFS** for fast, isolated filesystem mocking.

**Patterns:**
- Fixture-based: `spec/fixtures/*.yml` samples
- Command: Verify shell command construction
- Runner: Mock execution, verify arguments
- Config: Schema validation, merging logic

**Commands:**
```bash
bundle exec rspec spec/lib/hip/config_spec.rb       # Config tests
bundle exec rspec spec/lib/hip/commands/            # All commands
bundle exec rspec --tag focus                       # Focused tests
```

---

## Constraints

### Ruby Version
- **Current**: Ruby >= 3.3 (v9.1.0)
- **CI**: Ruby 3.3, 3.4

### Quality Gates
- **Coverage**: SimpleCov 90% minimum (enforced)
- **Schema**: All hip.yml must validate against schema.json
- **Linting**: RuboCop must pass

### Naming
- Gem: "hip"
- Module: `Hip::`
- Binary: `hip`
- Config: `hip.yml`, `hip.override.yml`, `.hip/`

---

## Common Patterns

### Dynamic Command Routing

`hip shell` → CLI.start detects "shell" not in TOP_LEVEL_COMMANDS → prepends "run" → becomes `hip run shell`

Only works if "shell" defined in hip.yml interaction: section.

### Environment Interpolation

Commands support `$VAR` and `${VAR}`:
- `$HIP_OS` → linux, darwin, etc.
- `$HIP_WORK_DIR_REL_PATH` → relative path to hip.yml directory
- `$HIP_CURRENT_USER` → current user UID

### Module System

```yaml
# hip.yml
modules:
  - ruby
  - postgres

# .hip/ruby.yml
interaction:
  bundle:
    service: app
    command: bundle

# .hip/postgres.yml
interaction:
  psql:
    service: db
    command: psql
```

All merged, overrides win.

---

## Key CLI Commands

| Command | Purpose |
|---------|---------|
| `hip run CMD` | Execute interaction command |
| `hip ls` | List available commands |
| `hip compose CMD` | Docker Compose wrapper |
| `hip provision [PROFILE]` | Run provisioning scripts |
| `hip validate` | Validate hip.yml schema |
| `hip devcontainer` | VSCode DevContainer integration |
| `hip claude:setup` | Generate Claude Code files |

---

**For detailed navigation:** See `CONTEXT_MAP.md`
**For architecture deep dive:** Read source files with headers (Phase 1.4)
**For examples:** See `examples/` directory
