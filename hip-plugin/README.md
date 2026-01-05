# Hip Plugin for Claude Code

Hip CLI integration - Docker Compose and Kubernetes workflow automation.

## Installation

```bash
/plugin marketplace add archmagece/hip
/plugin install hip@hip-marketplace
```

## Requirements

- Hip gem: `gem install hip`
- Docker/Docker Compose
- kubectl (optional)

## Feature

**hip-project skill**: Auto-detects `hip.yml` and provides all Hip CLI commands.

## Local Test

```bash
claude --plugin-dir ./hip-plugin
```
