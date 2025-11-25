# Commands Directory Guide

Quick reference for LLMs navigating Hip command implementations.

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `run.rb` | 53 | Main command dispatcher, runner selection |
| `compose.rb` | 92 | Docker Compose wrapper, DNS lookup, env setup |
| `kubectl.rb` | 20 | Kubernetes wrapper with namespace options |
| `provision.rb` | 53 | Execute provisioning scripts from hip.yml |
| `list.rb` | 11 | List available interaction commands |
| `console.rb` | 116 | Generate shell aliases for bash/zsh |
| `dns.rb` | 64 | DNS lookup utilities |
| `ssh.rb` | 60 | SSH agent container management |
| `infra.rb` | 82 | Infrastructure service orchestration |
| `down_all.rb` | 12 | Shutdown all Docker Compose projects |

---

## Subdirectories

### runners/
Execution strategy implementations. See `runners/AGENTS.md`.

### claude/
- `setup.rb` (219 lines) - Generate Claude Code integration files

### devcontainer/
- `init.rb`, `sync.rb`, `validate.rb`, `shell.rb`, `info.rb`, `features.rb`, `provision.rb`
- VSCode DevContainer integration commands

---

## Command Pattern

All commands inherit from `Hip::Command` base class:

```ruby
module Hip
  module Commands
    class MyCommand < Hip::Command
      def initialize(*args, **options)
        @args = args
        @options = options
      end

      def execute
        # Implementation using:
        # exec_program(*cmd)   # Replace current process
        # exec_subprocess(*cmd) # Spawn subprocess
      end
    end
  end
end
```

---

## Key Flows

### run.rb Flow
1. Parse command name and arguments
2. Lookup in InteractionTree (hip.yml interaction: section)
3. Merge environment variables
4. Select runner (lookup_runner method):
   - command[:runner] → explicit runner
   - command[:service] → DockerComposeRunner
   - command[:pod] → KubectlRunner
   - else → LocalRunner
5. Execute via runner

### compose.rb Flow
1. Find DNS resolver (`find_dns`)
2. Discover compose files (`compose_files`)
3. Build docker compose command with:
   - Project name/directory options
   - File paths
   - Infra network environment
4. Execute via `exec_program`

### provision.rb Flow
1. Load provision scripts from hip.yml
2. Filter by profile if specified
3. Execute each command sequentially
4. Report success/failure

---

## Adding a New Command

1. **Create file:** `lib/hip/commands/my_command.rb`
   ```ruby
   module Hip
     module Commands
       class MyCommand < Hip::Command
         def initialize(*args)
           @args = args
         end

         def execute
           # Implementation
         end
       end
     end
   end
   ```

2. **Register in CLI:** `lib/hip/cli.rb`
   ```ruby
   desc "my-command", "Description"
   def my_command(*argv)
     require_relative "commands/my_command"
     Hip::Commands::MyCommand.new(*argv).execute
   end
   ```

3. **Add tests:** `spec/lib/hip/commands/my_command_spec.rb`

4. **Update schema:** If command uses hip.yml config, update `schema.json`

---

## Common Patterns

### Environment Variable Interpolation
Commands support `$VAR` and `${VAR}` via `Hip.env.interpolate`:
```ruby
command = Hip.env.interpolate(command, argv)
```

### Shell vs. Array Execution
```ruby
# Shell execution (default)
exec_program("echo", ["hello"], shell: true)
# Produces: echo hello

# Array execution (no shell)
exec_program("echo", ["hello"], shell: false)
# Produces: ["echo", "hello"]
```

### Error Handling
```ruby
raise Hip::Error, "Descriptive error message"
```

---

## Testing Tips

- Use FakeFS for filesystem mocking
- Mock Hip.config with fixture data
- Verify command construction, not actual execution
- Test error cases and edge conditions

Example:
```ruby
describe Hip::Commands::MyCommand do
  include FakeFS::SpecHelpers

  it "constructs correct command" do
    cmd = described_class.new("arg1")
    expect(Hip::Command).to receive(:exec_program)
      .with(/expected command/)
    cmd.execute
  end
end
```

---

**See also:**
- `lib/hip/cli.rb` - Command registration
- `lib/hip/command.rb` - Base class
- `runners/AGENTS.md` - Execution strategies
