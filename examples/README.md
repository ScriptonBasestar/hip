# Hip Configuration Examples

This directory contains comprehensive examples of Hip configurations for various use cases and project types. Each example demonstrates different features and best practices.

## Quick Start

If you're new to Hip, start with [`basic.yml`](basic.yml) - it contains the essential commands you'll need for a simple Rails project.

## Examples by Use Case

### 🎯 Getting Started

- **[basic.yml](basic.yml)** - Simple Rails project configuration
  - Perfect for beginners
  - Essential commands: shell, rails, bundle, rake
  - Single provision profile
  - Use when: Starting a new Rails project or learning Hip

### 🚀 Full-Stack Applications

- **[full-stack.yml](full-stack.yml)** - Comprehensive Rails + Node.js configuration
  - Rails backend + React/Vue frontend
  - Multiple Docker Compose files
  - Complex subcommand structures
  - Advanced provision profiles (default, reset, seed, deploy)
  - Kubernetes and infra management
  - Use when: Building production-ready full-stack applications

### ☸️ Kubernetes Environments

- **[kubernetes.yml](kubernetes.yml)** - Kubernetes-focused configuration
  - kubectl runner examples
  - Pod targeting
  - Namespace configuration
  - Port forwarding and log streaming
  - Deployment and rollback provisions
  - Use when: Developing against Kubernetes clusters

### 🟢 Node.js Projects

- **[nodejs.yml](nodejs.yml)** - Node.js/Express application
  - npm and yarn command examples
  - MongoDB and Redis integration
  - Development and production modes
  - TypeScript support
  - Use when: Building Node.js applications

## Examples by Feature

### 📦 Provision Profiles

- **[provision-profiles.yml](provision-profiles.yml)** - Comprehensive provision examples
  - Multiple named profiles: default, reset, seed, test, ci, deploy
  - Each profile serves a different purpose
  - Demonstrates best practices for project automation
  - Use when: You need different setup scenarios (development, testing, CI/CD)

### 🧩 Module System

- **[modules/](modules/)** - Modular configuration example
  - **[main.yml](modules/main.yml)** - Main configuration importing modules
  - **[.hip/sast.yml](modules/.hip/sast.yml)** - Static analysis and security tools module
  - **[.hip/testing.yml](modules/.hip/testing.yml)** - Testing framework module
  - Use when: Large projects with shared configurations across teams

## Using These Examples

### 1. Copy an Example

```bash
# Copy an example to your project root
cp examples/basic.yml ./hip.yml

# Or for modules
cp -r examples/modules/main.yml ./hip.yml
cp -r examples/modules/.hip ./
```

### 2. Customize for Your Project

Edit the copied file to match your:
- Service names in docker-compose.yml
- Database credentials
- Port numbers
- Commands and scripts

### 3. Validate Your Configuration

```bash
# Validate your hip.yml
hip validate

# Or validate a specific example
hip validate -c examples/basic.yml
```

## Configuration File Structure

All examples follow this general structure:

```yaml
version: '8.2.8'              # Minimum required dip version

environment:                  # Environment variables
  VAR_NAME: value

compose:                      # Docker Compose configuration
  files:
    - docker-compose.yml
  project_name: myapp

interaction:                  # Interactive commands
  command-name:
    description: What this does
    service: container-name
    command: actual command
    subcommands:              # Optional nested commands
      sub-name:
        command: sub command

provision:                    # Setup automation
  profile-name:
    - command 1
    - command 2

kubectl:                      # Kubernetes config (optional)
  namespace: myapp-dev

modules:                      # Module imports (optional)
  - module-name

infra:                        # Infrastructure services (optional)
  service-name:
    git: repo-url
```

## Common Patterns

### Environment Variables

```yaml
environment:
  # Static values
  RAILS_ENV: development

  # With defaults
  PORT: ${PORT:-3000}

  # References
  DATABASE_URL: postgres://user:password@db:5432/myapp_development
```

### Subcommands

```yaml
interaction:
  rails:
    command: bundle exec rails
    subcommands:
      console:
        command: console
      db:
        subcommands:
          migrate:
            command: db:migrate
```

### Provision Profiles

```yaml
provision:
  default:              # 'hip provision' or 'hip provision default'
    - hip compose up -d
    - hip bundle install

  reset:                # 'hip provision reset'
    - hip compose down --volumes
    - hip compose build --no-cache
```

## Validation

All examples in this directory are validated against the schema. You can validate any example:

```bash
# Validate a specific example
HIP_FILE=examples/basic.yml hip validate

# Validate all examples
for file in examples/*.yml; do
  echo "Validating $file..."
  HIP_FILE=$file hip validate
done
```

## Tips and Best Practices

1. **Start Simple**: Begin with `basic.yml` and add features as needed
2. **Use Provision Profiles**: Create profiles for different scenarios (development, testing, deployment)
3. **Document Your Commands**: Use `description` fields to help team members
4. **Leverage Subcommands**: Organize related commands hierarchically
5. **Version Control**: Commit your `hip.yml` to share with your team
6. **Modules for Scale**: Use modules for large projects with many commands
7. **Validate Often**: Run `hip validate` after making changes

## Contributing

Found a bug in an example or have a suggestion for a new one? Please open an issue or pull request!

## Learn More

- [Hip Documentation](https://github.com/bibendi/dip)
- [Schema Reference](../schema.json)
- [Roadmap](../docs/ROADMAP.md)

---

**Version**: 8.2.8
**Last Updated**: January 2025
