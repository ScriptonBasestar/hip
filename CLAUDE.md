# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hip is a Ruby gem (formerly "dip") that provides a CLI tool for Docker and Kubernetes development workflows. It's a fork of [bibendi/dip](https://github.com/bibendi/dip), renamed for easier one-handed typing in Korean keyboards.

**Core Purpose**: Simplifies Docker Compose and Kubernetes interactions by wrapping complex commands into simple, configurable CLI shortcuts defined in `dip.yml` files.

## Development Commands

### Setup
```bash
bundle install                    # Install dependencies
dip provision                     # Run provisioning (defined in dip.yml)
```

### Testing
```bash
bundle exec rspec                 # Run all tests
bundle exec rspec spec/path/to/file_spec.rb         # Run specific test file
bundle exec rspec spec/path/to/file_spec.rb:42      # Run specific test at line
```

### Code Quality
```bash
bundle exec rubocop               # Run linter
bundle exec rubocop -a            # Auto-fix linting issues
```

### Build & Release
```bash
rake build                        # Build gem into pkg/
rake install:local                # Install gem locally without network
rake release                      # Tag version and push to RubyGems
```

### Using Hip on Itself (Dogfooding)
```bash
dip shell                         # Open bash in Docker container
dip pry                          # Open Pry console
dip bundle <command>             # Run bundler commands in container
dip rspec <args>                 # Run specs in container
dip rubocop <args>               # Run rubocop in container
```

## Architecture

### Core Components

**`lib/dip.rb`**: Entry point that initializes Config, Environment, and Logger.

**`lib/dip/cli.rb`**: Thor-based CLI interface. Maps user commands to command classes.

**`lib/dip/config.rb`**: Parses `dip.yml` configuration files. Handles:
- Config file discovery (walks up directory tree)
- Module system (loads `.dip/*.yml` files)
- Override files (`dip.override.yml`)
- Schema validation via `schema.json`

**`lib/dip/commands/`**: Command implementations:
- `run.rb`: Executes interaction commands defined in `dip.yml`
- `compose.rb`: Docker Compose wrapper
- `kubectl.rb`: Kubernetes wrapper
- `provision.rb`: Runs provisioning scripts
- `console.rb`: Shell integration (bash/zsh aliases)
- `infra.rb`: Manages shared infrastructure services
- `ssh.rb`: SSH agent container management

**`lib/dip/commands/runners/`**: Execution strategies:
- `docker_compose_runner.rb`: Runs commands via Docker Compose
- `kubectl_runner.rb`: Runs commands in Kubernetes pods
- `local_runner.rb`: Executes commands on host machine

**`lib/dip/environment.rb`**: Manages environment variables, including predefined ones:
- `DIP_OS`: Current OS (linux, darwin, etc.)
- `DIP_WORK_DIR_REL_PATH`: Relative path to config directory
- `DIP_CURRENT_USER`: Current user UID

**`lib/dip/interaction_tree.rb`**: Parses command hierarchy (commands and subcommands) from configuration.

### Configuration System

Hip uses a hierarchical configuration model:

1. **Base config**: `dip.yml` (searched up directory tree)
2. **Modules**: `.dip/*.yml` files (merged into base config)
3. **Overrides**: `dip.override.yml` (local customizations, git-ignored)

The `interaction` section defines commands that map to three runner types:
- **service**: Uses Docker Compose runner
- **pod**: Uses Kubectl runner
- **command**: Uses local runner (when neither service nor pod specified)

### Key Design Patterns

**Command Pattern**: Each CLI subcommand is a separate class in `lib/dip/commands/`.

**Strategy Pattern**: Runners provide different execution strategies (Docker Compose, Kubectl, local shell).

**Template Method**: `Dip::Command` base class provides common command infrastructure; subclasses implement specific behavior.

**Configuration as Code**: The `dip.yml` schema defines infrastructure commands declaratively, validated by JSON Schema.

## Important Constraints

### Ruby Version Compatibility
- **Current**: Requires Ruby >= 2.7
- **Future**: Version 9.0 will require Ruby >= 3.2 (see `docs/ROADMAP.md`)
- **Dependencies**: `public_suffix < 6.0` pinned for Ruby 2.7 compatibility

### Testing Requirements
- SimpleCov enforces minimum 90% code coverage
- Uses FakeFS for filesystem mocking in tests
- Tests must pass before release

### Naming Conventions
- Gem name is "hip" but internal module is still `Dip` (for backward compatibility)
- Binary is still `dip` (installed via `exe/dip`)
- All internal references use `Dip::` namespace

### Schema Validation
- All `dip.yml` files must validate against `schema.json`
- Validation can be skipped via `DIP_SKIP_VALIDATION` env var
- VSCode users can enable inline validation with YAML language server

## File Structure Notes

```
lib/dip/
├── cli.rb                    # Thor CLI entry point
├── config.rb                 # Configuration parser and validator
├── environment.rb            # Environment variable management
├── command.rb                # Base command class
├── commands/                 # Command implementations
│   ├── run.rb               # Execute interaction commands
│   ├── compose.rb           # Docker Compose wrapper
│   ├── kubectl.rb           # Kubernetes wrapper
│   ├── provision.rb         # Provisioning scripts
│   ├── console.rb           # Shell integration
│   ├── infra.rb             # Infrastructure management
│   └── runners/             # Execution strategies
│       ├── docker_compose_runner.rb
│       ├── kubectl_runner.rb
│       └── local_runner.rb
└── interaction_tree.rb       # Command hierarchy parser

examples/                     # Example dip.yml configurations
├── basic.yml                # Simple Rails setup
├── full-stack.yml           # Rails + Node.js
├── kubernetes.yml           # K8s integration
└── modules/                 # Modular config examples

spec/                        # RSpec tests
└── fixtures/                # Test fixtures (sample dip.yml files)
```

## Development Workflow

1. **Make changes** to Ruby files in `lib/`
2. **Write tests** in `spec/` with matching file structure
3. **Run tests** to verify: `bundle exec rspec`
4. **Check coverage**: SimpleCov report in `coverage/index.html`
5. **Lint code**: `bundle exec rubocop -a`
6. **Update schema** if changing `dip.yml` structure (edit `schema.json`)
7. **Update examples** if adding new features (in `examples/`)

## Common Development Patterns

### Adding a New Command

1. Create command class in `lib/dip/commands/new_command.rb`
2. Inherit from `Dip::Command` or `Thor`
3. Register in `lib/dip/cli.rb`
4. Add schema definition to `schema.json` if config-driven
5. Add tests in `spec/lib/dip/commands/new_command_spec.rb`
6. Update examples if user-facing

### Adding a New Runner

1. Create runner in `lib/dip/commands/runners/new_runner.rb`
2. Implement `#execute` method
3. Update `lib/dip/commands/run.rb` to detect when to use new runner
4. Add tests with fixtures

### Modifying Configuration Schema

1. Edit `schema.json` with new properties
2. Update `lib/dip/config.rb` if parsing logic changes
3. Add validation tests in `spec/lib/dip/config_spec.rb`
4. Create example in `examples/` directory
5. Document in README.md

## Testing Strategy

Tests use **FakeFS** to mock filesystem operations, enabling fast, isolated tests without real files.

**Key test patterns:**
- Fixture-based: Load sample `dip.yml` files from `spec/fixtures/`
- Command testing: Verify correct shell commands are constructed
- Runner testing: Mock Docker/Kubectl execution, verify arguments
- Config testing: Ensure schema validation and merging logic

**Run specific test suites:**
```bash
bundle exec rspec spec/lib/dip/config_spec.rb       # Config tests
bundle exec rspec spec/lib/dip/commands/            # All command tests
bundle exec rspec --tag focus                       # Tests marked with :focus
```
