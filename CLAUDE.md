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
bundle install               # Setup dependencies
bundle exec rspec            # Test (90% coverage enforced)
bundle exec rubocop [-a]     # Lint [auto-fix]
rake build / install:local   # Build/install gem
hip shell/rspec/rubocop      # Run in container
```

---

## Architecture

### Components

- **CLI**: `lib/hip/cli.rb` - Thor routing, TOP_LEVEL_COMMANDS
- **Config**: `lib/hip/config.rb` - hip.yml parsing, modules, validation
- **Dispatch**: `lib/hip/commands/run.rb` - InteractionTree → runner
- **Runners**: `lib/hip/commands/runners/` - Docker/Kubectl/Local strategies
- **Environment**: `lib/hip/environment.rb` - $VAR interpolation
- **Tree**: `lib/hip/interaction_tree.rb` - interaction: hierarchy

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

Command (CLI classes), Strategy (Runners), Template Method (Hip::Command), Configuration as Code (hip.yml)

---

## Extending Hip

### Add Command
1. `lib/hip/commands/my_command.rb` inherit `Hip::Command`
2. Register in `lib/hip/cli.rb`: desc + method → .execute
3. Test: `spec/lib/hip/commands/my_command_spec.rb`

### Add Runner
1. `lib/hip/commands/runners/my_runner.rb` inherit Base, impl #execute
2. Update `lib/hip/commands/run.rb` lookup_runner logic
3. Test with FakeFS fixtures

### Modify Schema
1. Edit `schema.json` + `lib/hip/config.rb` (if top-level key)
2. Add tests + example in `examples/`

---

## Testing

**FakeFS** for filesystem mocking. Fixtures: `spec/fixtures/*.yml`. Coverage: 90% enforced.

```bash
bundle exec rspec spec/lib/hip/{config,commands}/   # Targeted
bundle exec rspec --tag focus                       # Focused
```

---

## Constraints

**Ruby**: >= 3.3 (CI: 3.3, 3.4) | **Coverage**: 90% | **Lint**: RuboCop | **Schema**: schema.json
**Naming**: gem/bin: "hip", module: `Hip::`, config: `hip.yml`, `hip.override.yml`, `.hip/`

---

## Common Patterns

### Dynamic Routing

`hip shell` → auto-prepends "run" if not in TOP_LEVEL_COMMANDS → `hip run shell` (requires hip.yml entry)

### Environment Variables

`$VAR` / `${VAR}`: `$HIP_OS` (platform), `$HIP_WORK_DIR_REL_PATH` (rel path), `$HIP_CURRENT_USER` (UID)

### Module System

`hip.yml` → modules: [ruby, postgres] → loads `.hip/ruby.yml`, `.hip/postgres.yml` → merged (overrides win)

---

## Key CLI Commands

`hip run CMD` | `hip ls` | `hip up/down [SVC]` | `hip provision [PROF]` | `hip compose CMD`
`hip validate` (schema) | `hip devcontainer` (VSCode) | `hip claude:setup` (CodeGen)

---

**For detailed navigation:** See `CONTEXT_MAP.md`
**For architecture deep dive:** Read source files with headers (Phase 1.4)
**For examples:** See `examples/` directory
