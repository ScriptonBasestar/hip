# RFC: Provision Step Syntax

## Summary

Introduce a structured `step/run/note` syntax for provision commands to improve readability and reduce boilerplate.

## Motivation

Current provision syntax requires verbose echo commands:

```yaml
provision:
  default:
    - 'echo "📦 Step 1: Installing gems..."'
    - hip bundle install
    - 'echo ""'
    - 'echo "📦 Step 2: Setting up database..."'
    - hip rails db:create
```

Problems:
- Repetitive `echo` commands
- Manual step numbering
- Quote escaping issues
- No structured output formatting

## Proposed Syntax

### Basic Step

```yaml
provision:
  default:
    - step: Installing Ruby gems
      run: hip bundle install
```

### Multiple Commands

```yaml
- step: Setting up database
  run:
    - hip rails db:create
    - hip rails db:migrate
```

### Step with Note (no command)

```yaml
- step: Setup complete
  note: |
    Next steps:
      hip rails server    # Start server
      hip rails console   # Open console
```

### Step with Both Run and Note

```yaml
- step: Installing dependencies
  note: This may take a few minutes
  run: hip bundle install
```

## Output Format

```
📦 [1/4] Installing Ruby gems
   → hip bundle install
   ... (command output)

📦 [2/4] Setting up database
   → hip rails db:create
   → hip rails db:migrate
   ... (command output)

✅ [3/4] Setup complete
   ℹ️  Next steps:
      hip rails server    # Start server
      hip rails console   # Open console
```

## Schema

```json
{
  "provision": {
    "type": "object",
    "additionalProperties": {
      "type": "array",
      "items": {
        "oneOf": [
          { "type": "string" },
          {
            "type": "object",
            "properties": {
              "step": { "type": "string" },
              "run": {
                "oneOf": [
                  { "type": "string" },
                  { "type": "array", "items": { "type": "string" } }
                ]
              },
              "note": { "type": "string" }
            },
            "required": ["step"]
          },
          { "$ref": "#/definitions/legacy_provision_commands" }
        ]
      }
    }
  }
}
```

## Backward Compatibility

Existing formats remain supported:

```yaml
# Legacy string format (still works)
- 'echo "Hello"'
- hip bundle install

# Legacy structured format (still works)
- echo: "Hello"
- cmd: hip bundle install

# New step format
- step: Installing gems
  run: hip bundle install
```

## Implementation

### Detection Logic

```ruby
def execute_command(command)
  case command
  when String
    exec_subprocess(command)
  when Hash
    if command.key?(:step) || command.key?("step")
      execute_step(command)
    else
      execute_structured_command(command)  # legacy
    end
  end
end
```

### Step Execution

```ruby
def execute_step(step_config)
  step_name = step_config[:step] || step_config["step"]
  run_cmds = step_config[:run] || step_config["run"]
  note = step_config[:note] || step_config["note"]

  # Print step header
  puts "📦 [#{@current_step}/#{@total_steps}] #{step_name}"

  # Print note if present
  if note
    note.each_line { |line| puts "   ℹ️  #{line}" }
  end

  # Execute commands if present
  if run_cmds
    commands = run_cmds.is_a?(Array) ? run_cmds : [run_cmds]
    commands.each do |cmd|
      puts "   → #{cmd}"
      exec_subprocess(cmd)
    end
  end
end
```

## Examples

### Full Example

```yaml
provision:
  default:
    - step: Provisioning development environment
      note: |
        Prerequisites:
        - Docker and Docker Compose installed
        - Run 'hip up -d' first

    - step: Installing Ruby gems
      run: hip bundle install

    - step: Installing Node.js packages
      run: hip pnpm install

    - step: Setting up database
      run:
        - hip rails db:create
        - hip rails db:migrate
        - hip rails db:seed

    - step: Complete
      note: |
        ✅ Development environment ready!

        Start server: hip rails server
        Open console: hip rails console

  reset:
    - step: Resetting database
      run:
        - hip rails db:drop
        - hip rails db:create
        - hip rails db:migrate
```

## Alternatives Considered

### A. GitHub Actions Style (`name/run`)

```yaml
- name: Install gems
  run: bundle install
```

Rejected: `name` is less intuitive than `step` for provision context.

### B. Ansible Style (`name/command`)

```yaml
- name: Install gems
  command: bundle install
```

Rejected: `command` conflicts with existing hip command terminology.

### C. Simple String Detection

```yaml
- "# Installing gems"  # Comment = step header
- hip bundle install
```

Rejected: Less explicit, harder to parse notes.

## Migration Path

1. v9.2.0: Add step syntax support (backward compatible)
2. Document new syntax in examples
3. Gradually migrate existing examples
4. No deprecation of legacy syntax planned

## References

- GitHub Actions workflow syntax
- Ansible playbook syntax
- Docker Compose healthcheck syntax
