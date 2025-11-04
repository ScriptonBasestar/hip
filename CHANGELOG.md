# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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
