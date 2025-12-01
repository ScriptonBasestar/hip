# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`env_file` support**: Load environment variables from .env files
  - Simple form: `env_file: .env`
  - Multiple files: `env_file: [.env.defaults, .env, .env.local]`
  - Priority control: `before_environment` (default) or `after_environment`
  - Per-file required flag: `{ path: .env, required: true }`
  - Variable interpolation: `$VAR` and `${VAR}` expansion
  - Interaction-level env_file: command-specific environment files
  - Examples: `examples/env-file-*.yml`
  - RFC document: `docs/proposals/env-file-feature.md`

- **Debug mode**: `--debug` flag to display executed commands
  - Shows exact Docker Compose/kubectl commands before execution
  - Visual separators with 🔍 emoji for clarity
  - Helps troubleshoot workflow issues
  - Usage: `hip --debug up`, `hip --debug down`

## [9.1.2] - 2025-12-01

### Added

- **`hip clean` command**: Remove all containers, networks, and optionally volumes
  - Resolves container name conflicts caused by Docker Compose project name mismatches
  - Flags: `--volumes/-v` (remove volumes), `--images/-i` (remove images), `--force/-f` (skip confirmation)
  - Interactive confirmation prompt by default (unless `--force` is used)
  - Helps resolve common `hip up` failures due to existing containers

- **`hip up` smart defaults**: Automatically runs in detached mode with health checks
  - Default options: `-d --wait` (runs in background, waits for services to be healthy)
  - Use `--foreground/-f` flag to disable default behavior
  - Configurable via `compose.up_options` in hip.yml
  - Example: `compose: { up_options: ["--build", "-d"] }`

### Changed

- **Makefile structure**: Refactored monolithic `Makefile.dev.mk` into modular `.make/*.mk` directory structure
  - Split 151-line Makefile into 10 focused, categorized files for better maintainability
  - Categories: build, install, test, lint, ci, dev, status, hip-examples, release, help
  - Main `Makefile` now uses include system to aggregate all targets
  - All existing targets preserved and verified working

### Added

#### LLM/AI Friendliness Improvements

**Command Discovery & Introspection**
- **`hip run --explain`**: Show command execution plan without running
  - Displays command, description, runner type, service/pod, arguments, shell mode, and environment variables
  - Supports both explicit (`hip run --explain shell`) and shorthand (`hip shell --explain`) syntax
  - Short form: `-e` flag
  - Helps users and LLMs understand what will be executed before running

- **`hip ls --format`**: Multiple output formats for command listing
  - `--format table` (default): Human-readable table format
  - `--format json`: Structured JSON output for scripts and LLM tools
  - `--format yaml`: YAML output for configuration tools
  - Short form: `-f` flag

- **`hip ls --detailed`**: Enhanced command information display
  - Shows runner type (DockerCompose, Kubectl, Local)
  - Shows target (service:name, pod:name, or local)
  - Shows actual command to execute
  - Short form: `-d` flag

- **`hip manifest`**: Complete command registry with metadata
  - Generates comprehensive machine-readable command manifest
  - Includes static commands, subcommand groups, dynamic commands from hip.yml, and runner metadata
  - Output formats: JSON (default) or YAML
  - Enables LLMs to discover and understand all Hip commands without parsing source code
  - Useful for shell completion generators, documentation tools, and CI/CD scripts

**Documentation for LLMs**
- **`CONTEXT_MAP.md`**: LLM navigation guide for efficient file discovery
  - Reduces token usage by 65-70% for typical command queries
  - Quick reference by task type (modifying CLI, adding commands, updating config, etc.)
  - File size reference and directory structure overview
  - Replaces need to read multiple files with single context map

- **`AGENTS.md` files**: Added to key directories (lib/hip/commands/, lib/hip/commands/runners/, lib/hip/cli/)
  - Explains component purpose and organization
  - Lists all files with line counts
  - Guides for adding new commands and runners

- **Standardized file headers**: Added to 10 core Ruby files
  - `@file`: File path
  - `@purpose`: Component responsibility
  - `@flow`: Execution flow context
  - `@dependencies`: Required dependencies
  - `@key_methods`: Important methods

- **CLAUDE.md refactoring**: Restructured for tiered, token-efficient reading
  - TL;DR section for quick overview
  - Development Commands reference
  - Architecture overview
  - Removed verbosity while maintaining essential information

#### Token Efficiency Impact
- **Command discovery**: ~70% token reduction (single `hip manifest` vs multiple file reads)
- **Command understanding**: ~50% token reduction (`hip run --explain` vs trial-and-error)
- **Format conversion**: ~60% token reduction (native JSON/YAML vs parsing table output)

### Changed
- Enhanced `hip run` command with options documentation
- Enhanced `hip ls` command with multiple output formats and detail levels
- Improved dynamic command routing to preserve option flags

## [9.1.0] - 2025-11-25

### Changed

#### Ruby Version Requirement
- **Minimum Ruby version**: 2.7 → **3.3** (Breaking change)
- Drops support for Ruby 2.7, 3.0, 3.1, 3.2
- CI matrix updated to test Ruby 3.3 and 3.4

#### Dependencies Updated
- `json-schema`: ~> 5 → **~> 6.0**
- `public_suffix`: >= 2.0.2, < 6.0 → **>= 6.0**

#### Configuration
- RuboCop target version updated to 3.3

### Migration Guide

Users upgrading from 9.0.x need:
1. **Ruby >= 3.3** - Update your Ruby version
2. Run `bundle update` to get new dependencies

No code or configuration changes required - `hip.yml` format remains compatible.

---

## [9.0.0] - 2025-11-25

### Added

#### Claude Code Integration
- **`hip claude:setup` Command**: Generate Claude Code integration files for seamless AI-assisted development
- **Auto-generated Documentation**: Creates `.claude/ctx/hip-project-guide.md` with project-specific commands
- **Slash Commands**: Adds `/hip` command for interactive help in Claude Code
- **Global Reference Guide**: Optional `~/.claude/ctx/HIP_QUICK_REFERENCE.md` with Hip basics
- **Auto-provisioning**: Automatically generates Claude files during first `hip provision` run
- **Project Context**: Claude Code can discover and understand Hip commands from `hip.yml` configuration
- **Git Integration**: `.claude/` directory automatically added to `.gitignore`

#### DevContainer Integration
- **Full DevContainer Support**: Seamless integration with VSCode DevContainers
- **Bidirectional Sync**: Keep `hip.yml` and `.devcontainer/devcontainer.json` synchronized
- **Feature Shortcuts**: Convenient aliases for common DevContainer features (e.g., `docker-in-docker`, `github-cli`)
- **Templates**: Quick-start templates for Ruby, Node.js, Python, Go, and full-stack projects
- **CLI Commands**: Complete devcontainer management from command line
  - `hip devcontainer init` - Generate devcontainer.json from hip.yml
  - `hip devcontainer sync` - Bidirectional configuration sync
  - `hip devcontainer validate` - Validate devcontainer.json
  - `hip devcontainer shell` - Open shell in devcontainer
  - `hip devcontainer provision` - Run postCreateCommand
  - `hip devcontainer features` - Manage DevContainer features
  - `hip devcontainer info` - Show configuration status

#### Configuration
- Added `devcontainer` section to `hip.yml` schema
- Support for all major DevContainer specification properties:
  - Container configuration (image, service, workspaceFolder)
  - Features with version control
  - VSCode customizations (extensions, settings)
  - Port forwarding
  - Lifecycle commands (postCreateCommand, postStartCommand, postAttachCommand)
  - Advanced options (mounts, runArgs)

#### Documentation
- Added comprehensive DevContainer documentation in README.md
- Added [examples/devcontainer.yml](examples/devcontainer.yml) with full configuration example
- Added 5 DevContainer templates in `lib/hip/templates/devcontainer/`

### Fixed
- **CLI validate command**: Fixed description and output message to reference `hip.yml` instead of `dip.yml`
- **README.md**: Fixed schema.json URL to point to ScriptonBasestar/hip repository
- **docs/ROADMAP.md**: Fixed GitHub issues link to point to ScriptonBasestar/hip
- **examples/*.yml**: Fixed schema.json URLs and command examples from `dip` to `hip`
- **examples/README.md**: Fixed Hip Documentation link
- **.ruby-version**: Updated from 3.3.6 to 3.3.10 for rbenv compatibility

### 🚨 BREAKING CHANGES - Complete Rebranding from "dip" to "hip"

This is a major breaking release that completely renames the project from "dip" to "hip" (Handy Infrastructure Provisioner).

#### What Changed
- **Binary name**: `dip` → `hip`
- **Module namespace**: `Dip::` → `Hip::`
- **Config files**: `dip.yml` → `hip.yml`, `dip.override.yml` → `hip.override.yml`
- **Module directory**: `.dip/` → `.hip/`
- **Home directory**: `~/.dip` → `~/.hip`
- **Environment variables**: All `DIP_*` → `HIP_*`
  - `DIP_FILE` → `HIP_FILE`
  - `DIP_HOME` → `HIP_HOME`
  - `DIP_ENV` → `HIP_ENV`
  - `DIP_SHELL` → `HIP_SHELL`
  - `DIP_SKIP_VALIDATION` → `HIP_SKIP_VALIDATION`
  - And more...

#### Migration Guide

**Option 1: Use the migration script** (Recommended)
```bash
gem install hip
./bin/migrate-from-dip  # or with --dry-run to preview
```

**Option 2: Manual migration**
```bash
# Rename config files
mv dip.yml hip.yml
mv dip.override.yml hip.override.yml  # if exists
mv .dip .hip  # if exists

# Migrate home directory
mv ~/.dip ~/.hip  # if exists

# Update shell configuration
# Change: eval "$(dip console)"
# To:     eval "$(hip console)"

# Update environment variables in scripts/CI
# All DIP_* → HIP_*
```

**Why this change?**
This project is a fork of the original "dip" gem, renamed for easier one-handed typing on Korean keyboards and to establish a clear identity as "Hip" (Handy Infrastructure Provisioner).

### Added
- Migration script: `bin/migrate-from-dip` to help users transition from dip to hip
- Comprehensive documentation updates reflecting the new "hip" branding
- Simplified CLAUDE.md focusing on hip instead of detailing original dip

## [8.2.8] - 2025-01-02

### Fixed
- **Provision Schema Validation**: Changed provision schema from array to object type with named profiles support
  - Old format: `provision: [commands...]` ❌
  - New format: `provision: { default: [commands...], reset: [...] }` ✅
- **Provision Command**: Fixed argv handling to properly receive arguments from CLI
  - Now correctly supports `dip provision [profile-name]`
  - Gracefully handles empty provision configurations
- **ROADMAP Documentation**: Corrected dependency classification
  - Separated Runtime Dependencies from Development Tools
  - Removed bundler from "Key Dependencies" (it's a development tool)

### Changed
- **Bundler Dependency**: Updated from `~> 2.5` to `>= 2.5` for better compatibility
  - Allows bundler 2.5, 2.6, 2.7+ (more flexible)
  - Aligns with conservative compatibility approach

### Added
- **Comprehensive Example Files**:
  - `examples/basic.yml` - Simple Rails starter for beginners
  - `examples/full-stack.yml` - Production-ready Rails + Node.js setup (renamed from dip.yml)
  - `examples/kubernetes.yml` - Kubernetes environment with kubectl runner
  - `examples/nodejs.yml` - Node.js/Express projects with MongoDB
  - `examples/provision-profiles.yml` - Provision profiles demonstration
  - `examples/modules/` - Module system examples:
    - `main.yml` - Main configuration with module imports
    - `.dip/sast.yml` - Static analysis and security tools module
    - `.dip/testing.yml` - Testing frameworks module
- **Documentation**:
  - `examples/README.md` - Comprehensive examples documentation with:
    - Quick start guide
    - Use case categorization
    - Feature-based examples
    - Configuration structure reference
    - Common patterns and best practices
    - Validation instructions
  - `docs/ROADMAP.md` - Future planning and Ruby 3.2+ migration roadmap
  - `CHANGELOG.md` - This file!
- **README Improvements**:
  - Updated version from 8.0 to 8.2.8
  - Added Configuration Examples section with links to all examples
  - Added Documentation section with links to guides and references

### Documentation
- All example files now include detailed headers with:
  - Use case description
  - Features list
  - Usage instructions
  - yaml-language-server schema reference
- Provision profiles now support multiple named scenarios:
  - `default` - Initial project setup
  - `reset` - Clean rebuild
  - `seed` - Database seeding
  - `test` - Test environment setup
  - `ci` - Continuous integration
  - `deploy` - Production deployment preparation
- Schema validation passing for all examples

### Technical Details
- **Test Coverage**: 94.78% (1452/1532 lines)
- **Schema Version**: JSON Schema Draft-06
- **Supported Ruby**: >= 2.7
- **Runtime Dependencies**: json-schema ~> 5, thor >= 0.20 < 2, public_suffix >= 2.0.2 < 6.0

---

## [8.2.7] - Previous Release

See original project releases: https://github.com/bibendi/dip/releases

---

## About This Fork

This is a fork of [bibendi/dip](https://github.com/bibendi/dip), renamed to "hip" for one-handed typing convenience.

**Original Project** by Evil Martians
**Fork Maintainer**: archmagece
