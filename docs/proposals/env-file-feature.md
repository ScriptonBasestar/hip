# RFC: env_file Feature for Hip CLI

**Status**: Proposal
**Created**: 2025-12-01
**Author**: Claude (Sonnet 4.5)

## Summary

Add support for `.env` file loading in Hip CLI with configurable priority system, allowing users to separate environment configuration from `hip.yml` and support different environment file patterns (`.env`, `.env.local`, `.env.production`, etc.).

---

## Motivation

### Current Limitations

1. **All env vars must be in `hip.yml`**: Forces mixing of:
   - Public configuration (committed)
   - Secret values (should be git-ignored)
   - Environment-specific overrides

2. **No standard `.env` file support**:
   - Docker Compose supports `env_file`
   - Most modern tools (Rails, Node.js) use `.env` files
   - Hip users must manage env vars in two places

3. **Override complexity**:
   - `hip.override.yml` works but requires YAML knowledge
   - Developers often just want simple `KEY=value` files

### Use Cases

**Use Case 1: Secrets Management**
```yaml
# hip.yml (committed)
environment:
  DATABASE_HOST: postgres
  DATABASE_PORT: 5432
  RAILS_ENV: development

# .env (git-ignored)
DATABASE_PASSWORD=super_secret_password
SECRET_KEY_BASE=long_random_string
AWS_ACCESS_KEY_ID=AKIA...
```

**Use Case 2: Multi-Environment**
```bash
# .env.development
NODE_ENV=development
API_URL=http://localhost:3000

# .env.production
NODE_ENV=production
API_URL=https://api.example.com
```

**Use Case 3: Team Overrides**
```bash
# hip.yml (team default)
environment:
  LOG_LEVEL: info

env_file: .env.defaults

# .env.defaults (committed)
ENABLE_CACHE=true

# .env.local (developer's machine, git-ignored)
LOG_LEVEL=debug
ENABLE_CACHE=false
```

---

## Design Proposal

### 1. Configuration Schema

#### 1.1 Top-Level `env_file`

```yaml
version: '9.0.0'

# Option 1: Simple string (single file)
env_file: .env

# Option 2: Array (multiple files, last wins)
env_file:
  - .env.defaults    # 1st: Base defaults
  - .env             # 2nd: General overrides
  - .env.local       # 3rd: Local machine overrides

# Option 3: Object with priority control
env_file:
  files:
    - .env.defaults
    - .env
    - .env.local
  priority: before_environment  # or 'after_environment'
  required: false  # Don't error if files missing
  interpolate: true  # Allow $VAR references in .env

environment:
  RAILS_ENV: development
  DATABASE_URL: postgres://localhost/myapp
```

#### 1.2 Interaction-Level `env_file`

```yaml
interaction:
  rails:
    description: Run Rails commands
    service: web
    command: bundle exec rails
    env_file: .env.rails  # Command-specific env file
    environment:
      RAILS_ENV: development

  rspec:
    description: Run tests
    service: web
    command: bundle exec rspec
    env_file:
      - .env.test
      - .env.test.local
    environment:
      RAILS_ENV: test
```

### 2. Priority System

#### 2.1 Default Priority Order (Recommended)

```
Lowest Priority (Base)
  ↓
1. hip.yml environment:           # Project defaults
  ↓
2. .hip/*.yml environment:        # Module defaults
  ↓
3. hip.override.yml environment:  # Local YAML overrides
  ↓
4. env_file (top-level):          # General env files
  ↓
5. env_file (interaction-level):  # Command-specific env files
  ↓
6. System ENV variables           # Runtime environment
  ↓
Highest Priority (Final)
```

**Rationale**:
- YAML provides structure and is committed
- env_file provides secrets and local overrides
- System ENV allows runtime control without file changes

#### 2.2 Configurable Priority

Allow users to change the priority relationship between `environment:` and `env_file:`:

```yaml
# Option A: env_file before environment (override with YAML)
env_file:
  files: [.env, .env.local]
  priority: before_environment  # default

environment:
  DATABASE_HOST: localhost  # This overrides .env values

# Option B: env_file after environment (override YAML with files)
env_file:
  files: [.env, .env.local]
  priority: after_environment

environment:
  DATABASE_HOST: localhost  # .env values override this
```

**Priority Modes**:

| Mode | Description | Use Case |
|------|-------------|----------|
| `before_environment` (default) | env_file loaded first, YAML can override | Secrets in .env, public config in YAML |
| `after_environment` | YAML loaded first, env_file can override | YAML provides defaults, .env overrides locally |

#### 2.3 Within Multiple env_files

When multiple files are specified, **later files override earlier files**:

```yaml
env_file:
  - .env.defaults     # BASE=1, SECRET=default
  - .env              # BASE=2 (overrides)
  - .env.local        # SECRET=local (overrides)

# Final result:
# BASE=2 (from .env)
# SECRET=local (from .env.local)
```

### 3. File Format Support

Support standard `.env` file format:

```bash
# .env file format

# Comments
# KEY=value pairs
DATABASE_HOST=localhost
DATABASE_PORT=5432

# Quotes (optional)
DATABASE_NAME="myapp_development"
DATABASE_USER='postgres'

# Empty values
OPTIONAL_KEY=

# Variable expansion (if interpolate: true)
DATABASE_URL=postgres://${DATABASE_USER}@${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_NAME}

# Multi-line values (not supported in v1)
# CERTIFICATE="-----BEGIN CERTIFICATE-----
# MIIDXTCCAkWgAwIBAgIJAKZ..."
```

**Supported**:
- ✅ Basic `KEY=value` format
- ✅ Comments (`#`)
- ✅ Empty values
- ✅ Quoted values (`"value"`, `'value'`)
- ✅ Variable expansion (`${VAR}`, `$VAR`)

**Not Supported (v1)**:
- ❌ Multi-line values
- ❌ Export syntax (`export KEY=value`)
- ❌ Command substitution (`KEY=$(command)`)

### 4. Error Handling

```yaml
env_file:
  files:
    - .env.defaults
    - .env
  required: false  # Don't error if missing (default)

# Or per-file
env_file:
  - path: .env.defaults
    required: true   # Error if missing
  - path: .env.local
    required: false  # Optional
```

**Behaviors**:

| Scenario | `required: true` | `required: false` (default) |
|----------|------------------|----------------------------|
| File exists | Load normally | Load normally |
| File missing | ❌ Error and exit | ⚠️ Warn (debug mode only) |
| File unreadable | ❌ Error and exit | ❌ Error and exit |

### 5. Schema Definition

```json
{
  "definitions": {
    "env_file": {
      "oneOf": [
        {
          "type": "string",
          "description": "Path to a single .env file"
        },
        {
          "type": "array",
          "items": { "type": "string" },
          "description": "Array of .env file paths (later files override earlier)"
        },
        {
          "type": "object",
          "properties": {
            "files": {
              "oneOf": [
                { "type": "string" },
                {
                  "type": "array",
                  "items": {
                    "oneOf": [
                      { "type": "string" },
                      {
                        "type": "object",
                        "properties": {
                          "path": { "type": "string" },
                          "required": { "type": "boolean", "default": false }
                        },
                        "required": ["path"]
                      }
                    ]
                  }
                }
              ]
            },
            "priority": {
              "type": "string",
              "enum": ["before_environment", "after_environment"],
              "default": "before_environment"
            },
            "required": {
              "type": "boolean",
              "default": false
            },
            "interpolate": {
              "type": "boolean",
              "default": true
            }
          },
          "required": ["files"]
        }
      ]
    }
  },
  "properties": {
    "env_file": {
      "$ref": "#/definitions/env_file"
    },
    "interaction": {
      "patternProperties": {
        "^[a-zA-Z0-9_-]+$": {
          "properties": {
            "env_file": {
              "$ref": "#/definitions/env_file"
            }
          }
        }
      }
    }
  }
}
```

---

## Implementation Plan

### Phase 1: Core Implementation

1. **Create `Hip::EnvFileLoader` class**
   - Parse `.env` file format
   - Support comments, quotes, empty values
   - Handle variable interpolation
   - Error handling for missing/unreadable files

2. **Integrate into `Hip::Config`**
   - Add `env_file` to schema
   - Load env_file(s) during config initialization
   - Merge into config hierarchy

3. **Update `Hip::Environment`**
   - Modify merge order to support priority modes
   - Add `merge_from_files` method
   - Update interpolation to handle env_file variables

### Phase 2: Priority System

1. **Implement priority modes**
   - `before_environment` (default)
   - `after_environment`

2. **Add per-file required flag**
   - Schema update for object syntax
   - Error vs warning handling

3. **Add debug logging**
   - Show which files loaded
   - Show final merged environment
   - Display priority order used

### Phase 3: Interaction-Level Support

1. **Add env_file to interaction schema**
2. **Merge interaction env_file during command execution**
3. **Test command-specific overrides**

### Phase 4: Documentation & Examples

1. **Update schema.json**
2. **Add examples/**
   - `env-file-basic.yml`
   - `env-file-priority.yml`
   - `env-file-multi-env.yml`
3. **Update README.md**
4. **Add migration guide**

---

## Examples

### Example 1: Basic Usage

```yaml
# hip.yml
version: '9.0.0'

env_file: .env

environment:
  RAILS_ENV: development

interaction:
  rails:
    service: web
    command: bundle exec rails
```

```bash
# .env
DATABASE_PASSWORD=secret123
SECRET_KEY_BASE=abcd1234...
```

**Result**: Both sources merged, System ENV > .env > environment

---

### Example 2: Multi-File with Priority

```yaml
# hip.yml
version: '9.0.0'

env_file:
  files:
    - .env.defaults    # Team defaults (committed)
    - .env             # General secrets (git-ignored)
    - .env.local       # Developer overrides (git-ignored)
  priority: before_environment
  required: false

environment:
  RAILS_ENV: development
  LOG_LEVEL: info  # Overrides .env values
```

```bash
# .env.defaults (committed)
ENABLE_CACHE=true
LOG_LEVEL=warn

# .env (git-ignored)
DATABASE_PASSWORD=secret
LOG_LEVEL=info

# .env.local (git-ignored)
LOG_LEVEL=debug
ENABLE_CACHE=false
```

**Priority Order**:
1. `.env.defaults`: `ENABLE_CACHE=true`, `LOG_LEVEL=warn`
2. `.env`: `LOG_LEVEL=info` (overrides warn)
3. `.env.local`: `LOG_LEVEL=debug`, `ENABLE_CACHE=false` (both override)
4. `environment:`: `LOG_LEVEL=info` (overrides all .env files!)

**Final Result**: `ENABLE_CACHE=false`, `LOG_LEVEL=info`

---

### Example 3: Command-Specific env_file

```yaml
# hip.yml
version: '9.0.0'

env_file: .env

interaction:
  rails:
    service: web
    command: bundle exec rails
    environment:
      RAILS_ENV: development

  rspec:
    service: web
    command: bundle exec rspec
    env_file: .env.test  # Test-specific overrides
    environment:
      RAILS_ENV: test
```

```bash
# .env (general)
DATABASE_HOST=localhost
DATABASE_NAME=myapp_development

# .env.test (test-specific)
DATABASE_NAME=myapp_test
RAILS_LOG_LEVEL=error
```

**When running `hip rspec`**:
1. Load `.env` (top-level)
2. Load `.env.test` (interaction-level, overrides)
3. Apply `environment:` from interaction
4. Apply System ENV

**Final for rspec**: `DATABASE_HOST=localhost`, `DATABASE_NAME=myapp_test`, `RAILS_ENV=test`

---

### Example 4: Required Files

```yaml
env_file:
  - path: .env.defaults
    required: true   # Must exist
  - path: .env.local
    required: false  # Optional
```

**Behavior**:
- Missing `.env.defaults` → ❌ Error: "Required env file not found: .env.defaults"
- Missing `.env.local` → ⚠️ Debug log only (if `--debug`)

---

## Alternatives Considered

### Alternative 1: Always Load `.env` (Implicit)

```yaml
# No env_file config needed
# Hip automatically loads .env, .env.local if present
```

**Pros**: Zero config, matches Node.js/Rails conventions
**Cons**: Magic behavior, harder to control priority, no flexibility

**Decision**: ❌ Rejected - Explicit is better than implicit

---

### Alternative 2: Single Priority Flag

```yaml
env_file_priority: high  # or 'low'
```

**Pros**: Simpler API
**Cons**: Less clear what "high" means, not extensible

**Decision**: ❌ Rejected - `before_environment`/`after_environment` is clearer

---

### Alternative 3: Numeric Priority

```yaml
env_file:
  files: .env
  priority: 50  # 0-100 scale

environment:
  priority: 60
```

**Pros**: Maximum flexibility
**Cons**: Complex, hard to remember numbers, over-engineered

**Decision**: ❌ Rejected - Two modes are sufficient

---

## Migration Path

### For Existing Users

**No breaking changes**: This feature is purely additive.

**Migration steps**:

1. **Move secrets to `.env`** (optional):
   ```bash
   # Before
   # hip.yml
   environment:
     DATABASE_PASSWORD: secret123

   # After
   # hip.yml
   env_file: .env
   environment:
     DATABASE_HOST: localhost

   # .env (git-ignored)
   DATABASE_PASSWORD=secret123
   ```

2. **Update `.gitignore`**:
   ```
   .env
   .env.local
   .env.*.local
   ```

3. **Test priority behavior**:
   ```bash
   hip --debug rails console
   # Check which env vars are loaded
   ```

---

## Open Questions

### Q1: Support for `dotenv` gem compatibility?

**Question**: Should we support all features of the `dotenv` gem?

**Answer**: Start minimal (Phase 1), add features based on demand:
- ✅ Basic KEY=value
- ✅ Comments
- ✅ Variable expansion
- ❌ Multi-line (defer to v2)
- ❌ Command substitution (security risk)

### Q2: Should `env_file` work with `hip provision`?

**Question**: How do env_file variables interact with provision scripts?

**Answer**: Yes, they should be available:
```yaml
env_file: .env

provision:
  default:
    - echo "Database: $DATABASE_HOST"  # Works
    - hip rails db:migrate              # Works
```

### Q3: Path resolution for env_file

**Question**: Relative to what?

**Answer**: Relative to `hip.yml` directory (consistent with compose files):
```yaml
env_file: .env          # Same dir as hip.yml
env_file: ../shared.env # Parent dir
env_file: /abs/path.env # Absolute path
```

---

## Success Metrics

1. **Adoption**: X% of projects use `env_file` within 6 months
2. **Issue reduction**: Fewer questions about "how to manage secrets"
3. **Documentation**: Clear examples and migration guide
4. **Performance**: No measurable startup time increase

---

## References

- Docker Compose `env_file`: https://docs.docker.com/compose/environment-variables/set-environment-variables/#use-the-env_file-attribute
- dotenv gem: https://github.com/bkeepers/dotenv
- Node.js dotenv: https://github.com/motdotla/dotenv
- Rails credentials: https://guides.rubyonrails.org/security.html#custom-credentials

---

## Changelog

- **2025-12-01**: Initial proposal created
