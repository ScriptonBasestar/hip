# Hip

> **Hip** (Handy Infrastructure Provisioner) - A CLI dev-tool for streamlined Docker and Kubernetes workflows.
>
> Forked from [bibendi/dip](https://github.com/bibendi/dip) and renamed for easier one-handed typing (한손으로 칠 수 있도록).

[![Original Project](https://img.shields.io/badge/forked%20from-bibendi%2Fdip-blue)](https://github.com/bibendi/dip)
[![Gem Version](https://badge.fury.io/rb/hip.svg)](https://badge.fury.io/rb/hip)

<img src="https://raw.githubusercontent.com/bibendi/dip/master/.github/logo.png" alt="hip logo" height="140" />

Hip is a CLI dev-tool that provides native-like interaction with a Dockerized application. It gives the feeling that you are working without using complex commands to run containers.

**Original project** by Evil Martians:
<a href="https://github.com/bibendi/dip">
<img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Original by Evil Martians" height="60" /></a>

## Presentations and examples

- [Local development with Docker containers](https://slides.com/bibendi/dip)
- [Dockerized Ruby on Rails application](https://github.com/Kuper-Tech/outbox-example-apps)
- Dockerized Node.js application: [one](https://github.com/bibendi/twinkle.js), [two](https://github.com/bibendi/yt-graphql-react-event-booking-api)
- [Dockerized Ruby gem](https://github.com/bibendi/schked)
- [Dockerizing Ruby and Rails development](https://evilmartians.com/chronicles/ruby-on-whales-docker-for-ruby-rails-development)
- [Reusable development containers with Docker Compose and Hip](https://evilmartians.com/chronicles/reusable-development-containers-with-docker-compose-and-dip)

### 📚 Configuration Examples

Check out our [comprehensive examples](examples/) covering various use cases:

- **[Basic Setup](examples/basic.yml)** - Perfect for beginners starting with Rails
- **[Full-Stack Application](examples/full-stack.yml)** - Rails + Node.js production setup
- **[Kubernetes](examples/kubernetes.yml)** - K8s development environment with kubectl runner
- **[Node.js](examples/nodejs.yml)** - Node.js/Express projects with MongoDB
- **[Provision Profiles](examples/provision-profiles.yml)** - Advanced automation patterns
- **[Module System](examples/modules/)** - Modular configurations for large projects

See [examples/README.md](examples/README.md) for detailed documentation and usage instructions.

[![asciicast](https://asciinema.org/a/210236.svg)](https://asciinema.org/a/210236)

## Installation

```sh
gem install hip
```

### Integration with shell

Hip can be injected into the current shell (ZSH or Bash).

```sh
eval "$(dip console)"
```

**IMPORTANT**: Beware of possible collisions with local tools. One particular example is supporting both local and Docker frontend build tools, such as Yarn. If you want some developer to run `yarn` locally and other to use Docker for that, you should either avoid adding the `yarn` command to the `hip.yml` or avoid using the shell integration for hybrid development.

After that we can type commands without `dip` prefix. For example:

```sh
<run-command> *any-args
compose *any-compose-arg
up <service>
ktl *any-kubectl-arg
provision
```

When we change the current directory, all shell aliases will be automatically removed. But when we enter back into a directory with a `hip.yml` file, then shell aliases will be renewed.

Also, in shell mode Hip is trying to determine manually passed environment variables. For example:

```sh
VERSION=20180515103400 rails db:migrate:down
```

You could add this `eval` at the end of your `~/.zshrc`, or `~/.bashrc`, or `~/.bash_profile`.
After that, it will be automatically applied when you open your preferred terminal.

## Usage

```sh
dip --help
dip SUBCOMMAND --help
```

### hip.yml

The configuration is loaded from `hip.yml` file. It may be located in a working directory, or it will be found in the nearest parent directory up to the file system root. If nearby places `hip.override.yml` file, it will be merged into the main config.

Also, in some cases, you may want to change the default config path by providing an environment variable `HIP_FILE`.

Below is an example of a real config.
Config file reference will be written soon.
Also, you can check out examples at the top.

```yml
# Required minimum dip version
version: '8.2.8'

environment:
  COMPOSE_EXT: development
  STAGE: "staging"

compose:
  files:
    - docker/docker-compose.yml
    - docker/docker-compose.$COMPOSE_EXT.yml
    - docker/docker-compose.$HIP_OS.yml
  project_name: bear

kubectl:
  namespace: rocket-$STAGE

interaction:
  shell:
    description: Open the Bash shell in app's container
    service: app
    command: bash
    compose:
      run_options: [no-deps]

  bundle:
    description: Run Bundler commands
    service: app
    command: bundle

  rake:
    description: Run Rake commands
    service: app
    command: bundle exec rake

  rspec:
    description: Run Rspec commands
    service: app
    environment:
      RAILS_ENV: test
    command: bundle exec rspec

  rails:
    description: Run Rails commands
    service: app
    command: bundle exec rails
    subcommands:
      s:
        description: Run Rails server at http://localhost:3000
        service: web
        compose:
          run_options: [service-ports, use-aliases]

  stack:
    description: Run full stack (server, workers, etc.)
    runner: docker_compose
    compose:
      profiles: [web, workers]

  sidekiq:
    description: Run sidekiq in background
    service: worker
    compose:
      method: up
      run_options: [detach]

  psql:
    description: Run Postgres psql console
    service: app
    default_args: db_dev
    command: psql -h pg -U postgres

  k:
    description: Run commands in Kubernetes cluster
    pod: svc/rocket-app:app-container
    entrypoint: /env-entrypoint
    subcommands:
      bash:
        description: Get a shell to the running container
        command: /bin/bash
      rails:
        description: Run Rails commands
        command: bundle exec rails
      kafka-topics:
        description: Manage Kafka topics
        pod: svc/rocket-kafka
        command: kafka-topics.sh --zookeeper zookeeper:2181

  setup_key:
    description: Copy key
    service: app
    command: cp `pwd`/config/key.pem /root/keys/
    shell: false # you can disable shell interpolations on the host machine and send the command as is

  clean_cache:
    description: Delete cache files on the host machine
    command: rm -rf $(pwd)/tmp/cache/*

provision:
  - dip compose down --volumes
  - dip clean_cache
  - dip compose up -d pg redis
  - dip bash -c ./bin/setup
```

### Predefined environment variables

#### $HIP_OS

Current OS architecture (e.g. `linux`, `darwin`, `freebsd`, and so on). Sometime it may be useful to have one common `docker-compose.yml` and OS-dependent Compose configs.

#### $HIP_WORK_DIR_REL_PATH

Relative path from the current directory to the nearest directory where a Hip config is found. It is useful when you need to mount a specific local directory to a container along with ability to change its working dir. For example:

```
- project_root
  |- hip.yml (1)
  |- docker-compose.yml (2)
  |- sub-project-dir
     |- your current directory is here <<<
```

```yml
# hip.yml (1)
environment:
  WORK_DIR: /app/${HIP_WORK_DIR_REL_PATH}
```

```yml
# docker-compose.yml (2)
services:
  app:
    working_dir: ${WORK_DIR:-/app}
```

```sh
cd sub-project-dir
dip run bash -c pwd
```

returned is `/app/sub-project-dir`.

#### $HIP_CURRENT_USER

Exposes the current user ID (UID). It is useful when you need to run a container with the same user as the host machine. For example:

```yml
# hip.yml (1)
environment:
  UID: ${HIP_CURRENT_USER}
```

```yml
# docker-compose.yml (2)
services:
  app:
    image: ruby
    user: ${UID:-1000}
```

The container will run using the same user ID as your host machine.

### Modules

Modules are defined as array in `modules` section of hip.yml, modules are stored in `.dip` subdirectory of hip.yml directory.

The main purpose of modules is to improve maintainability for a group of projects.
Imagine having multiple gems which are managed with dip, each of them has the same commands, so to change one command in dip you need to update all gems individualy.

With `modules` you can define a group of modules for dip.

For example having setup as this:

```yml
# ./hip.yml
modules:
 - sasts
 - rails

...
```

```yml
# ./.hip/sasts.yml
interaction:
  brakeman:
    description: Check brakeman sast
    command: docker run ...
```

```yml
# ./.hip/rails.yml
interaction:
  annotate:
    description: Run annotate command
    service: backend
    command: bundle exec annotate
```

Will be expanded to:

```yml
# resultant configuration
interaction:
  brakeman:
    description: Check brakeman sast
    command: docker run ...
  annotate:
    description: Run annotate command
    service: backend
    command: bundle exec annotate
```

Imagine `.dip` to be a submodule so it can be managed only in one place.

If you want to override module command, you can redefine it in hip.yml

```yml
# ./hip.yml
modules:
 - sasts

interaction:
  brakeman:
    description: Check brakeman sast
    command: docker run another-image ...
```

```yml
# ./.hip/sasts.yml
interaction:
  brakeman:
    description: Check brakeman sast
    command: docker run some-image ...
```

Will be expanded to:

```yml
# resultant configuration
interaction:
  brakeman:
    description: Check brakeman sast
    command: docker run another-image ...
```

Nested modules are not supported.

### dip run

Run commands defined within the `interaction` section of hip.yml

A command will be executed by specified runner. Hip has three types of them:

- `docker compose` runner — used when the `service` option is defined.
- `kubectl` runner — used when the `pod` option is defined.
- `local` runner — used when the previous ones are not defined.

```sh
dip run rails c
dip run rake db:migrate
```

Also, `run` argument can be omitted

```sh
dip rake db:migrate
```

You can pass in a custom environment variable into a container:

```sh
dip VERSION=12352452 rake db:rollback
```

Use options `-p, --publish=[]` if you need to additionally publish a container's port(s) to the host unless this behaviour is not configured at hip.yml:

```sh
dip run -p 3000:3000 bundle exec rackup config.ru
```

You can also override docker compose command by passing `HIP_COMPOSE_COMMAND` if you wish. For example if you want to use [`mutagen-compose`](https://mutagen.io/documentation/orchestration/compose) run `HIP_COMPOSE_COMMAND=mutagen-compose dip run`.

If you want to persist that change you can specify command in `compose` section of hip.yml :

```yml
compose:
  command: mutagen-compose

```

### dip ls

List all available run commands.

```sh
dip ls

bash     # Open the Bash shell in app's container
rails    # Run Rails command
rails s  # Run Rails server at http://localhost:3000
```

### dip provision

Run commands each by each from `provision` section of hip.yml

### dip compose

Run Docker Compose commands that are configured according to the application's hip.yml:

```sh
dip compose COMMAND [OPTIONS]

dip compose up -d redis
```

### dip infra

Runs shared Docker Compose services that are used by the current application. Useful for microservices.

There are several official infrastructure services available:
- [dip-postgres](https://github.com/bibendi/dip (original project)-postgres)
- [dip-kafka](https://github.com/bibendi/dip (original project)-kafka)
- [dip-nginx](https://github.com/bibendi/dip (original project)-nginx)

```yaml
# hip.yml
infra:
  foo:
    git: https://github.com/owner/foo.git
    ref: latest # default, optional
  bar:
    path: ~/path/to/bar
```

Repositories will be pulled to a `~/.hip/infra` folder. For example, for the `foo` service it would be like this: `~/.hip/infra/foo/latest` and clonned with the following command: `git clone -b <ref> --single-branch <git> --depth 1`.

Available CLI commands:

- `dip infra update` pulls updates from sources
- `dip infra up` starts all infra services
- `dip infra up -n kafka` starts a specific infra service
- `dip infra down` stops all infra services
- `dip infra down -n kafka` stops a specific infra service

### dip ktl

Run kubectl commands that are configured according to the application's hip.yml:

```sh
dip ktl COMMAND [OPTIONS]

STAGE=some dip ktl get pods
```

### dip ssh

Runs ssh-agent container based on https://github.com/whilp/ssh-agent with your ~/.ssh/id_rsa.
It creates a named volume `ssh_data` with ssh socket.
An application's docker-compose.yml should contains environment variable `SSH_AUTH_SOCK=/ssh/auth/sock` and connects to external volume `ssh_data`.

```sh
dip ssh up
```

docker-compose.yml

```yml
services:
  web:
    environment:
      - SSH_AUTH_SOCK=/ssh/auth/sock
    volumes:
      - ssh-data:/ssh:ro

volumes:
  ssh-data:
    external:
      name: ssh_data
```

if you want to use non-root user you can specify UID like so:

```
dip ssh up -u 1000
```

This especially helpful if you have something like this in your docker-compose.yml:

```yml
services:
  web:
    user: "1000:1000"
```

### dip validate

Validates your hip.yml configuration against the JSON schema. The schema validation helps ensure your configuration is correct and follows the expected format.

```sh
dip validate
```

The validator will check:

- Required properties are present
- Property types are correct
- Values match expected patterns
- No unknown properties are used

If validation fails, you'll get detailed error messages indicating what needs to be fixed.

You can skip validation by setting `HIP_SKIP_VALIDATION` environment variable.

Add `# yaml-language-server: $schema=https://raw.githubusercontent.com/bibendi/dip (original project)/refs/heads/master/schema.json` to the top of your hip.yml to get schema validation in VSCode. Read more about [YAML Language Server](https://github.com/redhat-developer/vscode-yaml?tab=readme-ov-file#associating-schemas).

### hip devcontainer

Hip provides seamless integration with VSCode DevContainers, enabling bidirectional synchronization between `hip.yml` and `.devcontainer/devcontainer.json`.

#### Features

- **Bidirectional Sync**: Keep hip.yml and devcontainer.json in sync
- **Feature Shortcuts**: Use simple names like `docker-in-docker` instead of full feature URLs
- **Templates**: Quick-start templates for Ruby, Node.js, Python, Go, and full-stack projects
- **CLI Commands**: Manage devcontainer configuration from command line

#### Quick Start

```sh
# Generate devcontainer.json from hip.yml
hip devcontainer init

# Use a template
hip devcontainer init --template ruby

# Sync configurations
hip devcontainer sync

# Validate devcontainer.json
hip devcontainer validate

# Open shell in devcontainer
hip devcontainer bash

# Run postCreateCommand
hip devcontainer provision

# View devcontainer info
hip devcontainer info

# List available features
hip devcontainer features --list
```

#### Configuration Example

```yaml
# hip.yml
devcontainer:
  enabled: true
  name: "My Rails App"
  service: app
  workspaceFolder: "/workspace"

  # Simple feature shortcuts
  features:
    docker-in-docker: {}
    github-cli:
      version: "latest"

  customizations:
    vscode:
      extensions:
        - rebornix.ruby
        - castwide.solargraph

  forwardPorts: [3000, 5432]
  postCreateCommand: "bundle install && rails db:setup"
```

See [examples/devcontainer.yml](examples/devcontainer.yml) for a complete example.

#### Available Templates

- `ruby` - Ruby/Rails development
- `node` - Node.js/JavaScript development
- `python` - Python development
- `go` - Go development
- `full-stack` - Full-stack with multiple languages

#### Feature Shortcuts

Hip provides convenient shortcuts for common DevContainer features:

- `docker-in-docker` → `ghcr.io/devcontainers/features/docker-in-docker:2`
- `github-cli` → `ghcr.io/devcontainers/features/github-cli:1`
- `node` → `ghcr.io/devcontainers/features/node:1`
- `python` → `ghcr.io/devcontainers/features/python:1`
- `go` → `ghcr.io/devcontainers/features/go:1`
- `kubectl` → `ghcr.io/devcontainers/features/kubectl-helm-minikube:1`

Use `hip devcontainer features --list` to see all available shortcuts.

### hip claude

Hip provides integration with Claude Code (claude.ai/code) to make Hip commands easily discoverable and usable within AI-assisted development workflows.

#### Features

- **Auto-generated Documentation**: Creates Claude-readable guides from your `hip.yml` configuration
- **Project-Specific Commands**: Generates `.claude/ctx/hip-project-guide.md` with available commands
- **Slash Commands**: Adds `/hip` command for interactive help in Claude Code
- **Global Reference**: Optional `~/.claude/ctx/HIP_QUICK_REFERENCE.md` for Hip basics
- **Auto-provisioning**: Automatically generates Claude files during `hip provision` (first run only)

#### Quick Start

```sh
# Generate Claude Code integration files for current project
hip claude:setup

# Also create global reference guide
hip claude:setup --global
```

#### What Gets Generated

After running `hip claude:setup`, you'll have:

**`.claude/ctx/hip-project-guide.md`** - Project-specific command reference
- Lists all available Hip commands from `hip.yml`
- Includes descriptions for each command
- Shows configured services and environment variables
- Auto-updated with `hip claude:setup`

**`.claude/commands/hip.md`** - Slash command for Claude Code
- Type `/hip` in Claude Code for interactive help
- Quick access to command documentation

**`~/.claude/ctx/HIP_QUICK_REFERENCE.md`** (optional with `--global`)
- Hip basics and command syntax
- Common patterns and examples
- Available across all projects

#### Usage in Claude Code

Once set up, Claude Code can:

1. **Discover commands**: Ask "What Hip commands are available?"
2. **Get help**: Use `/hip` slash command
3. **Understand context**: Reads project-specific configuration
4. **Suggest workflows**: Recommends appropriate Hip commands for tasks

#### Example

```yaml
# hip.yml
interaction:
  console:
    description: "Open Rails console"
    service: rails
    command: bin/rails console

  test:
    description: "Run test suite"
    service: rails
    command: bundle exec rspec
```

After `hip claude:setup`, Claude Code will know:
- `hip console` opens Rails console
- `hip test` runs the test suite
- Both commands use the `rails` service

#### Auto-Generation

Claude files are automatically generated when you run `hip provision` for the first time in a project. To regenerate after changing `hip.yml`:

```sh
hip claude:setup
```

**Note**: `.claude/` directory is automatically git-ignored as it contains auto-generated files.

## 📖 Documentation

- **[Configuration Examples](examples/README.md)** - Comprehensive examples for various use cases
- **[Development Roadmap](docs/ROADMAP.md)** - Future plans and Ruby 3.2+ migration strategy
- **[Schema Reference](schema.json)** - Configuration schema for validation
- **[Original Project](https://github.com/bibendi/dip (original project))** - Evil Martians' original dip project

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

Original project releases: https://github.com/bibendi/dip (original project)/releases
