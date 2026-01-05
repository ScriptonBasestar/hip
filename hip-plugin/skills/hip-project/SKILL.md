---
name: hip-project
description: |
  Hip CLI project automation. Use when:
  - Project has hip.yml file
  - Docker, container, compose, kubernetes, k8s tasks
  - Running services, shells, tests in containers
  - DevContainer setup or management
allowed-tools: Bash, Read, Grep, Glob
---

# Hip CLI Reference

Hip wraps Docker Compose/Kubernetes commands with shortcuts defined in `hip.yml`.

## Quick Detection

```bash
test -f hip.yml && hip ls || echo "Not a Hip project"
```

## Command Reference

### Core Docker Compose

| Command | Description |
|---------|-------------|
| `hip up [SERVICE]` | Start services (detached) |
| `hip down [OPTIONS]` | Stop services |
| `hip stop SERVICE` | Stop specific service |
| `hip build [SERVICE]` | Build images |
| `hip clean [OPTIONS]` | Remove containers, networks, volumes |
| `hip compose CMD` | Pass-through docker compose commands |

```bash
hip up                    # Start all
hip up app db             # Start specific services
hip down                  # Stop all
hip down -v               # Stop and remove volumes
hip build app             # Build app image
hip clean --volumes       # Full cleanup
hip compose logs -f app   # Follow logs
hip compose exec app bash # Direct shell
```

### Interactions (hip.yml defined)

| Command | Description |
|---------|-------------|
| `hip ls` | List available interactions |
| `hip run CMD [ARGS]` | Run interaction |
| `hip provision` | Execute provision section |

```bash
hip ls                    # Show all interactions
hip run shell             # Or just: hip shell
hip run rspec spec/       # Run with arguments
hip provision             # Setup commands
```

### Kubernetes

| Command | Description |
|---------|-------------|
| `hip ktl CMD` | Run kubectl commands |

```bash
hip ktl get pods
hip ktl logs -f pod-name
hip ktl exec -it pod-name -- /bin/bash
```

### DevContainer

| Command | Description |
|---------|-------------|
| `hip devcontainer init` | Generate devcontainer.json |
| `hip devcontainer sync` | Sync hip.yml ↔ devcontainer |
| `hip devcontainer validate` | Validate configuration |
| `hip devcontainer bash` | Shell into devcontainer |
| `hip devcontainer features` | Manage features |
| `hip devcontainer info` | Show config info |
| `hip devcontainer provision` | Run postCreateCommand |

```bash
hip devcontainer init --force    # Regenerate config
hip devcontainer sync            # Sync changes
hip devcontainer validate        # Check config
```

### Infrastructure

| Command | Description |
|---------|-------------|
| `hip infra up` | Start infra services |
| `hip infra down` | Stop infra services |
| `hip infra update` | Pull updates |

### SSH Agent

| Command | Description |
|---------|-------------|
| `hip ssh up` | Start ssh-agent container |
| `hip ssh down` | Stop ssh-agent |
| `hip ssh restart` | Restart ssh-agent |
| `hip ssh status` | Show status |

### Utilities

| Command | Description |
|---------|-------------|
| `hip validate` | Validate hip.yml schema |
| `hip manifest` | Output command manifest |
| `hip migrate` | Migration guide |
| `hip version` | Show version |
| `hip claude setup` | Generate Claude integration |
| `hip console start` | Shell integration |

## hip.yml Structure

```yaml
name: project-name
modules: [ruby, postgres]  # Load .hip/*.yml

docker_compose:
  file: docker-compose.yml

interaction:
  shell:
    service: app           # → DockerComposeRunner
    command: /bin/bash

  test:
    service: app
    command: bundle exec rspec

  deploy:
    pod: api-server        # → KubectlRunner
    command: /deploy.sh

  lint:
    command: rubocop       # → LocalRunner

provision:
  - bundle install
  - rails db:setup
```

## Runner Selection

| Key | Runner | Execution |
|-----|--------|-----------|
| `service:` | DockerComposeRunner | `docker compose exec` |
| `pod:` | KubectlRunner | `kubectl exec` |
| neither | LocalRunner | Direct host execution |

## Environment Variables

- `$HIP_OS` - Platform (linux/darwin)
- `$HIP_WORK_DIR_REL_PATH` - Relative path from hip.yml
- `$HIP_CURRENT_USER` - Current UID

## Common Workflows

### New Project Setup
```bash
# Create hip.yml, then:
hip validate              # Check config
hip up                    # Start services
hip provision             # Run setup commands
```

### Daily Development
```bash
hip up                    # Start
hip shell                 # Enter container
hip run rspec             # Run tests
hip down                  # Stop when done
```

### Troubleshooting
```bash
hip validate              # Check config errors
hip compose logs -f       # Check logs
hip compose ps            # Container status
hip clean && hip up       # Fresh start
```
