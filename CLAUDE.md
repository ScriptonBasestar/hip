# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hip (Handy Infrastructure Provisioner) is a Ruby gem that provides a CLI tool for Docker and Kubernetes development workflows. Forked from [bibendi/dip](https://github.com/bibendi/dip).

**Core Purpose**: Simplifies Docker Compose and Kubernetes interactions by wrapping complex commands into simple, configurable CLI shortcuts defined in `hip.yml` files.

## Development Commands

### Setup
```bash
bundle install                    # Install dependencies
hip provision                     # Run provisioning (defined in hip.yml)
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
hip shell                         # Open bash in Docker container
hip pry                          # Open Pry console
hip bundle <command>             # Run bundler commands in container
hip rspec <args>                 # Run specs in container
hip rubocop <args>               # Run rubocop in container
```

## Architecture

### Core Components

**`lib/hip.rb`**: Entry point that initializes Config, Environment, and Logger.

**`lib/hip/cli.rb`**: Thor-based CLI interface. Maps user commands to command classes.

**`lib/hip/config.rb`**: Parses `hip.yml` configuration files. Handles:
- Config file discovery (walks up directory tree)
- Module system (loads `.hip/*.yml` files)
- Override files (`hip.override.yml`)
- Schema validation via `schema.json`

**`lib/hip/commands/`**: Command implementations:
- `run.rb`: Executes interaction commands defined in `hip.yml`
- `compose.rb`: Docker Compose wrapper
- `kubectl.rb`: Kubernetes wrapper
- `provision.rb`: Runs provisioning scripts
- `console.rb`: Shell integration (bash/zsh aliases)
- `infra.rb`: Manages shared infrastructure services
- `ssh.rb`: SSH agent container management

**`lib/hip/commands/runners/`**: Execution strategies:
- `docker_compose_runner.rb`: Runs commands via Docker Compose
- `kubectl_runner.rb`: Runs commands in Kubernetes pods
- `local_runner.rb`: Executes commands on host machine

**`lib/hip/environment.rb`**: Manages environment variables, including predefined ones:
- `HIP_OS`: Current OS (linux, darwin, etc.)
- `HIP_WORK_DIR_REL_PATH`: Relative path to config directory
- `HIP_CURRENT_USER`: Current user UID

**`lib/hip/interaction_tree.rb`**: Parses command hierarchy (commands and subcommands) from configuration.

### Configuration System

Hip uses a hierarchical configuration model:

1. **Base config**: `hip.yml` (searched up directory tree)
2. **Modules**: `.hip/*.yml` files (merged into base config)
3. **Overrides**: `hip.override.yml` (local customizations, git-ignored)

The `interaction` section defines commands that map to three runner types:
- **service**: Uses Docker Compose runner
- **pod**: Uses Kubectl runner
- **command**: Uses local runner (when neither service nor pod specified)

### Key Design Patterns

**Command Pattern**: Each CLI subcommand is a separate class in `lib/hip/commands/`.

**Strategy Pattern**: Runners provide different execution strategies (Docker Compose, Kubectl, local shell).

**Template Method**: `Hip::Command` base class provides common command infrastructure; subclasses implement specific behavior.

**Configuration as Code**: The `hip.yml` schema defines infrastructure commands declaratively, validated by JSON Schema.

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
- Gem name is "hip"
- Internal module is `Hip::`
- Binary is `hip` (installed via `exe/hip`)
- Config files: `hip.yml`, `hip.override.yml`, `.hip/`

### Schema Validation
- All `hip.yml` files must validate against `schema.json`
- Validation can be skipped via `HIP_SKIP_VALIDATION` env var
- VSCode users can enable inline validation with YAML language server

## File Structure Notes

```
lib/hip/
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

examples/                     # Example hip.yml configurations
├── basic.yml                # Simple Rails setup
├── full-stack.yml           # Rails + Node.js
├── kubernetes.yml           # K8s integration
└── modules/                 # Modular config examples

spec/                        # RSpec tests
└── fixtures/                # Test fixtures (sample hip.yml files)
```

## Development Workflow

1. **Make changes** to Ruby files in `lib/`
2. **Write tests** in `spec/` with matching file structure
3. **Run tests** to verify: `bundle exec rspec`
4. **Check coverage**: SimpleCov report in `coverage/index.html`
5. **Lint code**: `bundle exec rubocop -a`
6. **Update schema** if changing `hip.yml` structure (edit `schema.json`)
7. **Update examples** if adding new features (in `examples/`)

## Common Development Patterns

### Adding a New Command

1. Create command class in `lib/hip/commands/new_command.rb`
2. Inherit from `Hip::Command` or `Thor`
3. Register in `lib/hip/cli.rb`
4. Add schema definition to `schema.json` if config-driven
5. Add tests in `spec/lib/hip/commands/new_command_spec.rb`
6. Update examples if user-facing

### Adding a New Runner

1. Create runner in `lib/hip/commands/runners/new_runner.rb`
2. Implement `#execute` method
3. Update `lib/hip/commands/run.rb` to detect when to use new runner
4. Add tests with fixtures

### Modifying Configuration Schema

1. Edit `schema.json` with new properties
2. Update `lib/hip/config.rb` if parsing logic changes
3. Add validation tests in `spec/lib/hip/config_spec.rb`
4. Create example in `examples/` directory
5. Document in README.md

## Testing Strategy

Tests use **FakeFS** to mock filesystem operations, enabling fast, isolated tests without real files.

**Key test patterns:**
- Fixture-based: Load sample `hip.yml` files from `spec/fixtures/`
- Command testing: Verify correct shell commands are constructed
- Runner testing: Mock Docker/Kubectl execution, verify arguments
- Config testing: Ensure schema validation and merging logic

**Run specific test suites:**
```bash
bundle exec rspec spec/lib/hip/config_spec.rb       # Config tests
bundle exec rspec spec/lib/hip/commands/            # All command tests
bundle exec rspec --tag focus                       # Tests marked with :focus
```
