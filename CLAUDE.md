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

### Runner Internals

Runners are execution strategies in `lib/hip/commands/runners/`. Each inherits from `Base`.

**Base Class (`base.rb`):**
```ruby
class Base
  def initialize(command, argv, **options)
    @command = command   # Parsed interaction definition
    @argv = argv         # User-provided arguments
    @options = options   # CLI options (--publish, etc.)
  end

  def execute
    raise NotImplementedError  # Subclasses implement
  end

  def command_args  # Handle shell: true vs array args
    # Returns processed arguments based on shell mode
  end
end
```

**DockerComposeRunner** (`docker_compose_runner.rb`):
- Most complex runner (130+ lines)
- Auto-detects running containers → switches `run` to `exec`
- Handles profiles, environment variables, port publishing
- Wraps shell commands with `sh -c` for proper container execution

```ruby
# Key flow:
auto_detect_compose_method!  # run → exec if container running
compose_profiles             # --profile flags
compose_arguments            # --rm, -e vars, --publish, service, command
```

**KubectlRunner** (`kubectl_runner.rb`):
- Simple wrapper around `kubectl exec`
- Parses `pod:container` syntax
- Supports entrypoint override

```ruby
# pod: "my-pod:my-container" becomes:
kubectl exec --tty --stdin --container my-container my-pod -- command
```

**LocalRunner** (`local_runner.rb`):
- Simplest runner (~15 lines)
- Direct host execution via `Hip::Command.exec_program`
- No containerization

**Selection Logic** (in `lib/hip/commands/run.rb`):
```ruby
def lookup_runner(command)
  if command[:runner]     # Explicit runner
    # Custom runner from config
  elsif command[:service] # Docker service defined
    DockerComposeRunner
  elsif command[:pod]     # Kubernetes pod defined
    KubectlRunner
  else
    LocalRunner           # Default: local execution
  end
end
```

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

### Testing Philosophy

**Why FakeFS?**
- **Speed**: No real filesystem I/O = faster tests
- **Isolation**: Each test starts with clean filesystem state
- **Determinism**: No pollution from host filesystem

**Test Structure:**
```
spec/
├── fixtures/              # YAML fixtures for config testing
│   ├── empty/hip.yml     # Minimal valid config
│   ├── modules/          # Module loading tests
│   │   ├── hip.yml
│   │   └── .hip/*.yml
│   └── overridden/       # Override merging tests
├── support/
│   ├── fixtures_helper.rb           # fixture_path() helper
│   └── shared_contexts/
│       ├── config.rb                # Config stubbing
│       └── runner.rb                # Execution mocking
└── lib/hip/commands/     # Command specs (mirrored structure)
```

**Test Categories:**

| Type | Purpose | Key Pattern |
|------|---------|-------------|
| Config | Validate YAML parsing/merging | Use fixtures, check merged values |
| Runner | Verify command construction | Spy on `ProgramRunner`, check args |
| Command | End-to-end CLI behavior | Mock execution, verify outputs |
| Integration | Real system interactions | Skipped in CI (requires Docker) |

**Execution Mocking Pattern:**
```ruby
# Specs use shared context to stub execution
shared_context "dip command", :runner do
  let(:program_runner) { spy("program runner") }
  before { stub_const("Hip::Command::ProgramRunner", program_runner) }
end

# Verify expected commands were built correctly
expected_call("docker", ["compose", "run", "--rm", "app", "bundle"])
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

## Troubleshooting

### Common Development Issues

**"Could not find hip.yml config"**
- Hip walks up directory tree to find `hip.yml`
- Check you're in a subdirectory of a project with `hip.yml`
- Override with `HIP_FILE=/path/to/hip.yml`

**Schema validation errors**
```bash
hip validate                # Detailed validation output
HIP_DEBUG=1 hip <cmd>       # Full config dump
HIP_SKIP_VALIDATION=1 hip   # Skip validation (debugging only)
```

**"Container not found" when using run**
- Hip auto-detects running containers and switches to `exec`
- If container isn't running, `run` creates new container
- Check: `docker compose ps` to see container status

**Module not loading**
- Modules must be in `.hip/` directory (not `.hip.yml/`)
- Module filename must match array entry: `modules: [foo]` → `.hip/foo.yml`
- Nested modules not supported

**RuboCop failures in CI**
```bash
bundle exec rubocop -a      # Auto-fix most issues
bundle exec rubocop --only Layout  # Fix just layout issues
```

**Coverage below 90%**
- SimpleCov enforces minimum 90% in `spec_helper.rb`
- Check `coverage/index.html` for uncovered lines
- Focus on branch coverage, not just line coverage

### Debug Environment Variables

| Variable | Purpose |
|----------|---------|
| `HIP_DEBUG=1` | Enable debug logging, show config dump |
| `HIP_FILE=/path` | Override hip.yml location |
| `HIP_SKIP_VALIDATION=1` | Skip schema validation |
| `HIP_ENV=test` | Set environment (test disables some features) |

### Testing Gotchas

**FakeFS interference:**
- FakeFS is activated per-test, not globally
- Real filesystem ops (like `File.exist?`) may fail in FakeFS context
- Use `fixture_path()` helper for fixture files

**Shared context not loading:**
- Check `:runner` tag is applied to spec
- Verify `spec_helper.rb` is required

**Specs passing locally but failing in CI:**
- Check Ruby version match (3.3 vs 3.4)
- Docker may not be available in CI for integration tests
- Ensure no hardcoded paths

---

**For detailed navigation:** See `CONTEXT_MAP.md`
**For architecture deep dive:** Read source files with headers (Phase 1.4)
**For examples:** See `examples/` directory
