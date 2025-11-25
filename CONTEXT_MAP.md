# Hip Context Map - LLM Navigation Guide

**Purpose:** Help LLMs quickly locate relevant files based on task type, minimizing token usage.

---

## Quick Reference (Load First)

Start here for basic understanding:

| File | Lines | Purpose |
|------|-------|---------|
| `lib/hip.rb` | 47 | Entry point, global state (config, env, logger) |
| `lib/hip/cli.rb` | 156 | CLI routing, Thor commands, TOP_LEVEL_COMMANDS |
| `schema.json` | 377 | hip.yml structure validation |
| `CLAUDE.md` | 224 | Architecture overview, development guide |

---

## By Task Type

### Modifying CLI Commands

**Goal:** Add new command, modify routing, change CLI behavior

**Load these files:**
1. `lib/hip/cli.rb` - Main CLI entry, command registration
2. `lib/hip/commands/run.rb` - Dynamic command dispatch
3. `lib/hip/interaction_tree.rb` - hip.yml command parsing
4. `lib/hip/commands/{specific}_command.rb` - Target command

**Pattern:** `cli.rb` → register command → create `commands/{name}.rb` → inherit `Hip::Command`

### Modifying Command Execution (Runners)

**Goal:** Change how commands execute (Docker/Kubectl/Local)

**Load these files:**
1. `lib/hip/commands/run.rb` - Runner selection logic (lookup_runner)
2. `lib/hip/commands/runners/base.rb` - Runner interface
3. Target runner:
   - `lib/hip/commands/runners/docker_compose_runner.rb` (service: key)
   - `lib/hip/commands/runners/kubectl_runner.rb` (pod: key)
   - `lib/hip/commands/runners/local_runner.rb` (neither)

**Runner selection:** command[:runner] → explicit | command[:service] → Docker | command[:pod] → Kubectl | else → Local

### Modifying Config Parsing

**Goal:** Change hip.yml loading, merging, validation

**Load these files:**
1. `lib/hip/config.rb` - Config entry point, file discovery
2. `lib/hip/environment.rb` - Environment variable interpolation
3. `schema.json` - hip.yml validation rules
4. `lib/hip/interaction_tree.rb` - interaction: section parsing

**Config flow:** Find hip.yml → Load modules (.hip/*.yml) → Merge overrides → Validate schema

### Modifying DevContainer Integration

**Goal:** Change devcontainer.json generation/sync

**Load these files:**
1. `lib/hip/devcontainer.rb` - Main DevContainer class
2. `lib/hip/commands/devcontainer/*.rb` - Subcommands (init, sync, validate)
3. `lib/hip/cli/devcontainer.rb` - CLI interface

**DevContainer flow:** hip.yml devcontainer: → generate devcontainer.json → sync features

### Adding Tests

**Goal:** Write specs for new/changed functionality

**Load these files:**
1. `spec/spec_helper.rb` - Test configuration
2. `spec/support/*.rb` - Shared test utilities
3. `spec/fixtures/*.yml` - Sample hip.yml files
4. `spec/lib/hip/{matching_path}_spec.rb` - Target spec file

**Test pattern:** Use FakeFS for filesystem mocking, fixture-based hip.yml samples

### Debugging Command Flow

**Goal:** Trace how a specific command executes

**Load these files (in order):**
1. `exe/hip` - Entry script (22 lines)
2. `lib/hip.rb` - Module initialization
3. `lib/hip/cli.rb` - Thor routing, start method
4. `lib/hip/run_vars.rb` - ENV=value extraction
5. `lib/hip/commands/run.rb` - Command lookup
6. `lib/hip/interaction_tree.rb` - hip.yml command resolution
7. Appropriate runner file

### Understanding Architecture

**Goal:** High-level understanding of system design

**Load these files:**
1. `CLAUDE.md` - Architecture overview, patterns, constraints
2. `lib/hip.rb` - Global state management
3. `lib/hip/cli.rb` - Command structure
4. `lib/hip/command.rb` - Base command class
5. `lib/hip/commands/runners/base.rb` - Runner pattern

---

## File Size Reference

Quick reference for token estimation:

| Size Range | Files | Load Priority |
|------------|-------|---------------|
| < 50 lines | 15 files | Always safe to load |
| 50-100 lines | 18 files | Load when relevant |
| 100-200 lines | 5 files (cli.rb, config.rb, devcontainer.rb) | Load selectively |
| > 200 lines | 1 file (devcontainer.rb: 233 lines) | Load only when needed |

**Average file size:** ~68 lines
**Total codebase:** ~2,700 lines across 40 files

---

## Directory Structure

```
lib/hip/
├── cli.rb                    # Thor CLI entry point
├── cli/                      # CLI subcommand handlers
│   ├── base.rb              # Subcommand base class
│   ├── ssh.rb, infra.rb     # Service management
│   ├── devcontainer.rb      # VSCode integration
│   └── claude.rb            # Claude Code integration
├── command.rb               # Base command with exec utilities
├── commands/                # Command implementations
│   ├── run.rb              # Main command dispatcher
│   ├── compose.rb          # Docker Compose wrapper
│   ├── kubectl.rb          # Kubernetes wrapper
│   ├── provision.rb        # Provisioning scripts
│   └── runners/            # Execution strategies
│       ├── base.rb
│       ├── docker_compose_runner.rb
│       ├── kubectl_runner.rb
│       └── local_runner.rb
├── config.rb               # Configuration parser
├── devcontainer.rb         # DevContainer integration
├── environment.rb          # Environment variables
├── interaction_tree.rb     # Command hierarchy parser
├── run_vars.rb            # ENV=value parser
└── templates/             # DevContainer JSON templates
```

---

## Common Patterns

### Adding a New Command

1. Create `lib/hip/commands/my_command.rb` inheriting `Hip::Command`
2. Register in `lib/hip/cli.rb`:
   ```ruby
   desc "my-command", "Description"
   def my_command(*argv)
     require_relative "commands/my_command"
     Hip::Commands::MyCommand.new(*argv).execute
   end
   ```
3. Add tests in `spec/lib/hip/commands/my_command_spec.rb`

### Adding a New Runner

1. Create `lib/hip/commands/runners/my_runner.rb` inheriting `Base`
2. Implement `#execute` method
3. Update `lib/hip/commands/run.rb` `lookup_runner` logic
4. Add tests in `spec/lib/hip/commands/runners/my_runner_spec.rb`

### Extending hip.yml Schema

1. Update `schema.json` with new properties
2. Update `lib/hip/config.rb` if new top-level key
3. Update `lib/hip/interaction_tree.rb` if interaction: change
4. Add example in `examples/` directory
5. Update `README.md` documentation

---

## Key Concepts

**Dynamic Command Routing:**
- `hip shell` is automatically converted to `hip run shell`
- Only works if "shell" is in hip.yml interaction: section
- See `lib/hip/cli.rb` start method (lines 22-34)

**Runner Selection:**
- command[:runner] → use specified runner
- command[:service] → DockerComposeRunner
- command[:pod] → KubectlRunner
- else → LocalRunner

**Environment Interpolation:**
- Commands support `$VAR` and `${VAR}` syntax
- Special vars: `HIP_OS`, `HIP_WORK_DIR_REL_PATH`, `HIP_CURRENT_USER`
- See `lib/hip/environment.rb`

**Module System:**
- Base config: `hip.yml`
- Modules: `.hip/*.yml` (merged into base)
- Overrides: `hip.override.yml` (git-ignored, highest priority)

---

## Token Optimization Tips

**For simple queries:** Load only CONTEXT_MAP.md + target file

**For command changes:** Load cli.rb + target command file

**For runner changes:** Load run.rb + runners/base.rb + specific runner

**For config changes:** Load config.rb + schema.json

**Avoid loading:** Full file trees, multiple runners at once, all examples

---

**Last Updated:** 2025-01-25 (based on v9.1.0)
