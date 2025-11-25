# CLI Directory Guide

Thor-based CLI subcommand handlers.

---

## Main Entry

**`../cli.rb`** (156 lines) - Thor CLI, main command routing

Key features:
- `TOP_LEVEL_COMMANDS` whitelist
- Dynamic command routing (prepends "run" for unknown commands)
- Subcommand registration via `subcommand :name, ClassName`

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `base.rb` | 8 | Thor subcommand base class (sets exit_on_failure?) |
| `ssh.rb` | 75 | SSH agent container commands (up, down, restart, status) |
| `infra.rb` | 74 | Infrastructure service management (update, up, down) |
| `console.rb` | 34 | Shell integration (start, inject) |
| `devcontainer.rb` | 72 | VSCode DevContainer integration (7 subcommands) |
| `claude.rb` | 25 | Claude Code integration (setup) |

---

## Subcommand Pattern

All subcommand handlers inherit from `Hip::CLI::Base < Thor`:

```ruby
module Hip
  module CLI
    class MyGroup < Base
      desc "action", "Description"
      method_option :opt, type: :string, desc: "Option description"
      def action
        if options[:help]
          invoke :help, ["action"]
        else
          require_relative "../commands/my_group/action"
          Hip::Commands::MyGroup::Action.new(options).execute
        end
      end
    end
  end
end
```

---

## Subcommand Groups

### SSH (`ssh.rb`)

Commands for SSH agent container management:
- `up` - Start ssh-agent container with key mounting
- `down` - Stop ssh-agent container
- `restart` - Restart ssh-agent
- `status` - Show ssh-agent status

Options:
- `--key` - SSH key path
- `--volume` - Volume name
- `--interactive` - Interactive mode
- `--user` - User name

### Infra (`infra.rb`)

Infrastructure service orchestration:
- `update [NAME]` - Pull service updates
- `up [NAME]` - Start services (with optional update)
- `down [NAME]` - Stop services

Filters services by name from hip.yml infra: section.

### Console (`console.rb`)

Shell integration:
- `start` - Integrate Hip into current shell
- `inject` - Inject shell aliases

Generates bash/zsh aliases for interaction commands.

### DevContainer (`devcontainer.rb`)

VSCode DevContainer integration (7 subcommands):
- `init [--template] [--force]` - Generate devcontainer.json
- `sync [--direction]` - Sync with hip.yml
- `validate` - Validate devcontainer.json
- `bash [--user]` - Open shell in devcontainer
- `provision` - Run postCreateCommand
- `features [--list]` - Manage features
- `info` - Show devcontainer configuration

Uses `Hip::DevContainer` class for actual logic.

### Claude (`claude.rb`)

Claude Code integration:
- `setup [--global]` - Generate Claude integration files

Generates `.claude/` directory with context files.

---

## Adding a Subcommand Group

1. **Create file:** `lib/hip/cli/my_group.rb`
   ```ruby
   module Hip
     module CLI
       class MyGroup < Base
         desc "action ARG", "Description"
         method_option :opt, type: :string
         def action(arg)
           require_relative "../commands/my_group/action"
           Hip::Commands::MyGroup::Action.new(arg, options).execute
         end
       end
     end
   end
   ```

2. **Register in main CLI:** `lib/hip/cli.rb`
   ```ruby
   require_relative "cli/my_group"

   desc "my-group", "Group description"
   subcommand :my_group, Hip::CLI::MyGroup
   ```

3. **Create command classes:** `lib/hip/commands/my_group/action.rb`

4. **Add tests:** `spec/lib/hip/cli/my_group_spec.rb`

---

## Common Patterns

### Help Flag Handling

Repeated pattern in all subcommands:
```ruby
def action
  if options[:help]
    invoke :help, ["action"]
  else
    # Execute command
  end
end
```

### Option Passing

```ruby
MyCommand.new(
  arg: options[:arg],
  flag: options[:flag]
).execute
```

### Command Aliasing

```ruby
map add: :up  # `hip ssh add` becomes `hip ssh up`
```

### Default Task

```ruby
default_task :info  # Falls back to :info if no subaction
```

---

## Testing Tips

- Mock command classes to avoid execution
- Verify option parsing
- Test help flag behavior
- Test command aliasing

Example:
```ruby
describe Hip::CLI::MyGroup do
  it "passes options correctly" do
    expect(Hip::Commands::MyGroup::Action).to receive(:new)
      .with(hash_including(opt: "value"))

    described_class.start(["action", "--opt=value"])
  end
end
```

---

**See also:**
- `../cli.rb` - Main CLI routing
- `../commands/` - Command implementations
- Thor documentation for CLI features
