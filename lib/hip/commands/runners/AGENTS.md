# Runners Directory Guide

Execution strategy implementations for Hip commands.

---

## Runner Selection Logic

Located in `lib/hip/commands/run.rb` `lookup_runner` method:

```ruby
if command[:runner]
  # Explicit runner specified (camelized)
  Runners.const_get("#{camelized_runner}Runner")
elsif command[:service]
  # Docker Compose execution
  Runners::DockerComposeRunner
elsif command[:pod]
  # Kubernetes execution
  Runners::KubectlRunner
else
  # Local shell execution
  Runners::LocalRunner
end
```

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `base.rb` | 41 | Abstract base class, command_args helper |
| `docker_compose_runner.rb` | 98 | Execute via docker compose run/exec/up |
| `kubectl_runner.rb` | 20 | Execute in Kubernetes pod |
| `local_runner.rb` | 12 | Execute on host machine |

---

## Base Class Pattern

All runners inherit from `Hip::Commands::Runners::Base`:

```ruby
module Hip
  module Commands
    module Runners
      class Base
        attr_reader :command, :argv, :options

        def initialize(command, argv, **options)
          @command = command
          @argv = argv
          @options = options
        end

        def execute
          raise NotImplementedError
        end

        private

        def command_args
          # Build argument array from command and argv
        end
      end
    end
  end
end
```

---

## Runner Details

### DockerComposeRunner (98 lines)

**Purpose:** Execute commands in Docker Compose services

**Key Features:**
- Handles both `run` and `exec` methods
- Supports compose profiles (changes method to `up`)
- Injects environment variables (-e flags)
- Publishes ports (--publish flags)
- Handles user/workdir settings

**Flow:**
1. Check for profiles → use `up` instead of `run`
2. Build environment flags from command[:environment]
3. Add publish flags from options[:publish]
4. Construct compose command: `compose [method] [options] service -- command args`
5. Delegate to Hip::Commands::Compose

**hip.yml Config:**
```yaml
interaction:
  shell:
    service: web          # Triggers this runner
    command: /bin/bash
    compose:
      method: run         # Optional: run (default), exec, or up
      run_options:
        - --rm
```

### KubectlRunner (20 lines)

**Purpose:** Execute commands in Kubernetes pods

**Key Features:**
- Parses pod:container format
- Supports entrypoint override
- Uses kubectl exec with --tty --stdin

**Flow:**
1. Parse pod specification (format: `pod_name` or `pod_name:container`)
2. Build kubectl exec command
3. Add entrypoint if specified
4. Execute via Hip::Commands::Kubectl

**hip.yml Config:**
```yaml
interaction:
  console:
    pod: app-deployment:web  # Triggers this runner (pod:container)
    command: /bin/sh
```

### LocalRunner (12 lines)

**Purpose:** Execute commands directly on host

**Key Features:**
- Simple pass-through to shell
- No containerization

**Flow:**
1. Pass command and args directly to exec_program
2. Respects shell: true/false option

**hip.yml Config:**
```yaml
interaction:
  git-status:
    command: git status    # No service/pod = local runner
```

---

## Adding a New Runner

1. **Create runner file:** `lib/hip/commands/runners/my_runner.rb`
   ```ruby
   module Hip
     module Commands
       module Runners
         class MyRunner < Base
           def execute
             # Custom execution logic
             Hip::Command.exec_program(
               command[:command],
               command_args,
               shell: command.fetch(:shell, true)
             )
           end
         end
       end
     end
   end
   ```

2. **Update run.rb:** Modify `lookup_runner` to detect when to use new runner
   ```ruby
   def lookup_runner
     if command[:my_key]
       Runners::MyRunner
     elsif command[:service]
       # ... existing logic
   end
   ```

3. **Add tests:** `spec/lib/hip/commands/runners/my_runner_spec.rb`

4. **Update schema:** Add new config keys to `schema.json`

---

## Common Patterns

### Command Argument Building

```ruby
def command_args
  default_args = Shellwords.shellsplit(command[:default_args].to_s)
  cmd_args = Shellwords.shellsplit(command[:command].to_s)

  argv.empty? ? default_args : argv
end
```

### Environment Variable Injection

```ruby
env_options = command[:environment]&.flat_map do |k, v|
  ["-e", "#{k}=#{v}"]
end || []
```

### Shell vs. Array Execution

```ruby
if command[:shell]
  exec_program(cmd, args, shell: true)   # "cmd arg1 arg2"
else
  exec_program(cmd, args, shell: false)  # ["cmd", "arg1", "arg2"]
end
```

---

## Testing Tips

- Mock Hip::Commands::Compose/Kubectl to avoid actual execution
- Verify command construction with array matching
- Test environment variable injection
- Test port publishing options
- Test profile handling (DockerComposeRunner)

Example:
```ruby
describe Hip::Commands::Runners::DockerComposeRunner do
  it "constructs correct compose command" do
    command = { service: "web", command: "bash" }
    runner = described_class.new(command, [])

    expect(Hip::Commands::Compose).to receive(:new)
      .with("run", array_including("web", "--", "bash"))

    runner.execute
  end
end
```

---

**See also:**
- `lib/hip/commands/run.rb` - Runner selection
- `lib/hip/command.rb` - exec_program/exec_subprocess
- `../AGENTS.md` - Command patterns
