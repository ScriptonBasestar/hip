# Proposal: Add `compose.method` Support for Exec Mode

**Status**: Proposed
**Created**: 2025-12-01
**Related Issue**: Container name conflict in provision scripts
**Author**: Claude (claude-sonnet-4-5-20250929)

---

## Problem Statement

When provision scripts start containers with `docker compose up -d`, subsequent `hip` commands that use `service:` fail with container name conflicts because they try to create new containers instead of executing in existing ones.

**Current behavior:**
```yaml
provision:
  default:
    - docker compose up -d discourse
    - hip bundle install  # ❌ Fails - tries to create new container
```

**Error:**
```
Error response from daemon: Conflict.
The container name "/app" is already in use
```

---

## Solution: `compose.method` Configuration

Add support for specifying the Docker Compose execution method (`run` vs `exec`) in command configuration.

### Implementation

#### 1. Schema Update (`schema.json`)

```json
{
  "interaction": {
    "type": "object",
    "patternProperties": {
      ".*": {
        "properties": {
          "compose": {
            "type": "object",
            "properties": {
              "method": {
                "type": "string",
                "enum": ["run", "exec"],
                "description": "Docker Compose execution method (default: run)",
                "default": "run"
              },
              "run_options": {
                "type": "array",
                "description": "Options for docker compose run (e.g., --rm, --no-deps)"
              },
              "exec_options": {
                "type": "array",
                "description": "Options for docker compose exec (e.g., -T, --privileged)"
              }
            }
          }
        }
      }
    }
  }
}
```

#### 2. Configuration Example

**Option A: Explicit method per command**
```yaml
interaction:
  # Use exec for commands in running containers
  bundle:
    description: Run Bundler in running container
    service: app
    command: bundle
    compose:
      method: exec  # ✅ Use exec mode

  # Use run for one-off commands
  rake:
    description: Run Rake tasks
    service: app
    command: bundle exec rake
    compose:
      method: run  # ✅ Use run mode (default)
      run_options:
        - rm  # Clean up container after
```

**Option B: Global default with overrides**
```yaml
compose:
  default_method: exec  # Global default

interaction:
  bundle:
    service: app
    command: bundle
    # Inherits exec from global default

  test:
    service: app
    command: npm test
    compose:
      method: run  # Override for this specific command
      run_options:
        - rm
```

#### 3. Code Changes

**File: `lib/hip/commands/runners/docker_compose_runner.rb`**

```ruby
# frozen_string_literal: true
# @file: lib/hip/commands/runners/docker_compose_runner.rb
# @purpose: Docker Compose command execution with run/exec support

module Hip
  module Commands
    module Runners
      class DockerComposeRunner < Base
        def execute
          # Determine method: exec or run
          method = compose_method

          case method
          when "exec"
            exec_command
          when "run"
            run_command
          else
            raise Hip::Error, "Unknown compose method: #{method}"
          end
        end

        private

        def compose_method
          # Priority: command config > global config > default (run)
          command.dig(:compose, :method) ||
            Hip.config.compose.dig(:default_method) ||
            "run"
        end

        def exec_command
          # Check if container is running
          unless container_running?
            raise Hip::Error, "Container '#{service}' is not running. " \
                             "Use 'docker compose up -d #{service}' first or " \
                             "change compose.method to 'run'."
          end

          cmd = ["docker", "compose"]
          cmd.concat compose_arguments
          cmd << "exec"
          cmd.concat exec_options
          cmd << service
          cmd.concat command_args

          Hip.logger.debug "Exec command: #{cmd.join(' ')}"
          exec(*cmd)
        end

        def run_command
          # Existing run logic
          cmd = ["docker", "compose"]
          cmd.concat compose_arguments
          cmd << "run"
          cmd.concat run_options
          cmd << service
          cmd.concat command_args

          Hip.logger.debug "Run command: #{cmd.join(' ')}"
          exec(*cmd)
        end

        def exec_options
          command.dig(:compose, :exec_options) || []
        end

        def run_options
          # Existing run_options logic
          options = []
          options.concat(command.dig(:compose, :run_options) || [])
          options.concat(publish_options) if @options[:publish]
          options
        end

        def container_running?
          service_name = service
          result = `docker compose ps -q #{service_name}`.strip
          !result.empty?
        end

        def service
          command[:service]
        end
      end
    end
  end
end
```

#### 4. Usage in Provision Scripts

**Before (fails):**
```yaml
provision:
  default:
    - docker compose up -d app
    - hip bundle install  # ❌ Fails with container conflict
```

**After (works):**
```yaml
interaction:
  bundle:
    service: app
    command: bundle
    compose:
      method: exec  # ✅ Use exec for running containers

provision:
  default:
    - docker compose up -d app
    - sleep 5
    - hip bundle install  # ✅ Works - uses exec mode
```

---

## Benefits

### For Users
1. **Provision scripts work reliably** - No more container conflicts
2. **Clear intent** - Explicit `method: exec` documents assumption
3. **Flexible** - Mix run/exec modes based on use case
4. **Backward compatible** - Default is still `run`

### For Developers
1. **Better error messages** - Clear guidance when container not running
2. **Validation** - Check container state before exec
3. **Consistent** - Same hip command works in different contexts

---

## Migration Guide

### Identifying Commands That Need exec Mode

Commands that should use `exec`:
- ✅ Called after `docker compose up -d` in provision
- ✅ Expect persistent state in container
- ✅ Run in long-running services

Commands that should use `run`:
- ✅ One-off tasks
- ✅ Clean isolated execution needed
- ✅ Container cleanup desired (--rm)

### Step-by-Step Migration

1. **Identify problematic provision scripts**
   ```bash
   grep -r "docker compose up" */hip.yml
   grep -A 10 "provision:" */hip.yml
   ```

2. **Add exec mode to affected commands**
   ```yaml
   interaction:
     bundle:
       service: app
       command: bundle
       compose:
         method: exec  # Add this line
   ```

3. **Update provision scripts if needed**
   ```yaml
   provision:
     default:
       - docker compose up -d app  # Ensure container starts
       - sleep 5                   # Wait for ready
       - hip bundle install        # Now uses exec
   ```

4. **Test both modes**
   ```bash
   # Test exec mode (container must be running)
   docker compose up -d app
   hip bundle install

   # Test run mode (creates new container)
   docker compose down
   hip rake db:version  # If using method: run
   ```

---

## Alternative: Auto-Detection

Instead of explicit configuration, auto-detect based on container state:

```ruby
def execute
  if container_running? && !force_run_mode?
    exec_command
  else
    run_command
  end
end

def force_run_mode?
  command.dig(:compose, :method) == "run"
end
```

**Pros:**
- No configuration needed
- "Just works" in most cases

**Cons:**
- Implicit behavior harder to debug
- User intent unclear
- May surprise users

**Recommendation:** Use explicit configuration (original proposal) for predictability.

---

## Testing Strategy

### Unit Tests

```ruby
# spec/lib/hip/commands/runners/docker_compose_runner_spec.rb
describe Hip::Commands::Runners::DockerComposeRunner do
  describe "compose method selection" do
    it "uses exec when method is exec" do
      command = {service: "app", command: "bundle", compose: {method: "exec"}}
      runner = described_class.new(command, [])

      expect(runner).to receive(:exec_command)
      runner.execute
    end

    it "uses run when method is run" do
      command = {service: "app", command: "bundle", compose: {method: "run"}}
      runner = described_class.new(command, [])

      expect(runner).to receive(:run_command)
      runner.execute
    end

    it "defaults to run when method not specified" do
      command = {service: "app", command: "bundle"}
      runner = described_class.new(command, [])

      expect(runner).to receive(:run_command)
      runner.execute
    end
  end

  describe "#exec_command" do
    it "raises error when container not running" do
      command = {service: "app", command: "bundle", compose: {method: "exec"}}
      runner = described_class.new(command, [])

      allow(runner).to receive(:container_running?).and_return(false)

      expect { runner.execute }.to raise_error(Hip::Error, /not running/)
    end
  end
end
```

### Integration Tests

```bash
# Test provision workflow
cat > test-provision.yml <<EOF
version: '9.1.0'

compose:
  files:
    - docker-compose.yml

interaction:
  bundle:
    service: app
    command: bundle
    compose:
      method: exec

provision:
  default:
    - docker compose up -d app
    - sleep 2
    - hip bundle install
EOF

# Run test
HIP_FILE=test-provision.yml hip provision
```

---

## Documentation Updates

### README.md

Add section under "Commands and Configuration":

```markdown
### Compose Execution Methods

Hip supports two Docker Compose execution methods:

- **run** (default): Creates a new container for each command
- **exec**: Executes in an existing running container

Usage:

\`\`\`yaml
interaction:
  bundle:
    service: app
    command: bundle
    compose:
      method: exec  # Use exec for running containers
\`\`\`

When to use each method:
- Use **exec** for commands in long-running containers
- Use **run** for isolated one-off commands
\`\`\`
```

### Examples

Create `examples/provision-exec-mode.yml`:

```yaml
version: '9.1.0'

compose:
  files:
    - docker-compose.yml

# Commands that work with running containers
interaction:
  bundle:
    service: app
    command: bundle
    compose:
      method: exec  # Execute in running container

  rails:
    service: app
    command: bundle exec rails
    compose:
      method: exec

  # One-off commands still use run
  test:
    service: app
    command: bundle exec rspec
    compose:
      method: run  # Create new container for isolation
      run_options:
        - rm  # Clean up after test

provision:
  default:
    - echo "Starting services..."
    - docker compose up -d app db
    - sleep 5
    - echo "Installing dependencies..."
    - hip bundle install  # Uses exec - runs in existing container
    - echo "Setting up database..."
    - hip rails db:create  # Uses exec
    - hip rails db:migrate # Uses exec
    - echo "✅ Provision complete"
```

---

## Implementation Checklist

- [ ] Update `schema.json` with `compose.method` field
- [ ] Modify `DockerComposeRunner` to support exec/run methods
- [ ] Add `container_running?` check method
- [ ] Add error handling for exec on stopped containers
- [ ] Write unit tests for method selection
- [ ] Write integration tests for provision workflow
- [ ] Update README.md with compose methods section
- [ ] Create example configuration
- [ ] Update CHANGELOG.md
- [ ] Add migration guide for existing users

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking changes | High | Make `run` the default, requiring explicit opt-in for `exec` |
| Container state confusion | Medium | Clear error messages when exec on stopped container |
| Performance (ps check) | Low | Cache container state, add `--skip-check` option |
| Documentation confusion | Medium | Comprehensive examples and clear use case guidance |

---

## Future Enhancements

1. **Smart detection mode** - Auto-select based on container state
2. **Provision-specific defaults** - Different defaults for provision vs interactive
3. **Health check integration** - Wait for healthy before exec
4. **Service dependencies** - Auto-start dependencies for exec commands

---

## Related Work

- Docker Compose documentation: `run` vs `exec`
- Kubernetes: `kubectl run` vs `kubectl exec`
- Similar tools: Dip, DevContainer CLI

---

## Approval Process

1. Review by maintainers
2. Community feedback (issue discussion)
3. Prototype implementation
4. Testing with real projects
5. Documentation review
6. Merge and release

---

**Estimated Effort:** 4-6 hours
- Schema update: 30 min
- Runner implementation: 2-3 hours
- Tests: 1-2 hours
- Documentation: 1 hour
- Examples and validation: 1 hour
