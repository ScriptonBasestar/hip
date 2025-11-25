# Hip Development Roadmap

This document outlines planned features, improvements, and breaking changes for future versions of Hip (formerly Dip).

---

## Version History Context

- **Current**: 9.1.0 (November 2025)
- **Ruby Support**: >= 3.3
- **Runtime Dependencies**:
  - json-schema ~> 6.0
  - thor >= 0.20, < 2
  - public_suffix >= 6.0
- **Development Tools**: bundler >= 2.5, rspec ~> 3.13, standard ~> 1.0

---

## Planned Updates

### 🔮 Future: Ruby 3.4+ Features

**Status**: Planned (not scheduled)
**Target Version**: 10.0.0

Potential features for the next major version:
- YJIT optimization flags for improved performance
- Pattern matching enhancements
- Ruby 3.4+ specific improvements

---

## Completed Milestones

### ✅ v9.1.0 (November 2025) - Ruby 3.3+ Migration

**Impact**: ⚠️ Breaking change (Ruby version requirement)

#### What Changed

- **Minimum Ruby**: 2.7 → **3.3**
- **Dependencies Updated**:
  - `json-schema`: ~> 5 → ~> 6.0
  - `public_suffix`: >= 2.0.2, < 6.0 → >= 6.0
- **CI Matrix**: Ruby 3.3, 3.4 (dropped 2.7, 3.0, 3.1, 3.2)
- **RuboCop**: Target version updated to 3.3

#### Migration Guide

```bash
# 1. Check Ruby version
ruby -v  # Must be >= 3.3

# 2. Update Hip
gem update hip
# or in Gemfile
gem 'hip', '~> 9.1'

# 3. Update dependencies
bundle update
```

No `hip.yml` configuration changes required.

---

### ✅ v9.0.0 (November 2025)

- 🚨 **Breaking**: Complete rebranding from "dip" to "hip"
  - Binary: `dip` → `hip`
  - Config files: `dip.yml` → `hip.yml`
  - Environment variables: `DIP_*` → `HIP_*`
- ✨ Claude Code Integration (`hip claude:setup`)
- ✨ DevContainer Integration (`hip devcontainer`)
- 🐛 Multiple dip→hip migration fixes

### ✅ v8.2.8 (January 2025)

- Fixed provision schema validation issues
- Updated bundler dependency to ~> 2.7
- Improved provision command argv handling
- Maintained Ruby 2.7+ compatibility

### Previous Releases

See [CHANGELOG.md](../CHANGELOG.md) for complete version history.

---

## Contributing

Have suggestions for the roadmap? Please:

1. Open an issue on [GitHub](https://github.com/ScriptonBasestar/hip)
2. Discuss in existing roadmap issues
3. Submit a pull request with your proposal

---

## Maintenance Policy

- **Active Support**: Latest minor version (9.0.x)
- **Security Fixes**: Latest major version (9.x)
- **Ruby EOL Policy**: We aim to drop support 6-12 months after Ruby version EOL
