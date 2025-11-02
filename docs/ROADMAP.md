# Hip Development Roadmap

This document outlines planned features, improvements, and breaking changes for future versions of Hip (formerly Dip).

---

## Version History Context

- **Current**: 8.2.8 (January 2025)
- **Ruby Support**: >= 2.7
- **Runtime Dependencies**:
  - json-schema ~> 5
  - thor >= 0.20, < 2
  - public_suffix >= 2.0.2, < 6.0
- **Development Tools**: bundler >= 2.5, rspec ~> 3.13, standard ~> 1.0

---

## Planned Updates

### 🔮 Future: Ruby 3.2+ Migration

**Status**: Planned (not scheduled)
**Target Version**: 9.0.0 (major version bump)
**Impact**: ⚠️ Breaking change

#### Motivation

- json-schema v6.0+ requires Ruby >= 3.2
- Ruby 2.7 reached EOL on 2023-03-31
- Ruby 3.0 reaches EOL on 2024-03-31
- Ruby 3.1 reaches EOL on 2025-03-31

#### Changes Required

**Dependencies to Update:**
- `json-schema`: ~> 5 → ~> 6.0
- `public_suffix`: >= 2.0.2, < 6.0 → >= 6.0 (no upper bound needed)

**Gemspec Changes:**
```diff
- spec.required_ruby_version = ">= 2.7"
+ spec.required_ruby_version = ">= 3.2"

- spec.add_dependency "json-schema", "~> 5"
+ spec.add_dependency "json-schema", "~> 6.0"

- spec.add_dependency "public_suffix", ">= 2.0.2", "< 6.0"
+ spec.add_dependency "public_suffix", ">= 6.0"
```

**CI/CD Updates:**
- Remove Ruby 2.7, 3.0, 3.1 from test matrix
- Add Ruby 3.4+ to test matrix

#### Migration Guide (Draft)

Users upgrading from 8.x to 9.0 will need to:

1. **Upgrade Ruby version**
   ```bash
   # Check current Ruby version
   ruby -v

   # Required: Ruby >= 3.2
   # Recommended: Ruby 3.3+
   ```

2. **Update Hip**
   ```bash
   gem update dip
   # or in Gemfile
   gem 'dip', '~> 9.0'
   ```

3. **No configuration changes required**
   - hip.yml format remains compatible
   - All commands work the same way

#### Timeline

This update will be considered when:
- [ ] Majority of users have migrated to Ruby 3.2+
- [ ] Ruby 3.1 approaches EOL (2025-03-31)
- [ ] Community feedback indicates readiness

**Related Issues**: (Link to GitHub issue when created)

---

## Completed Milestones

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

1. Open an issue on [GitHub](https://github.com/bibendi/dip)
2. Discuss in existing roadmap issues
3. Submit a pull request with your proposal

---

## Maintenance Policy

- **Active Support**: Latest minor version (8.2.x)
- **Security Fixes**: Latest major version (8.x)
- **Ruby EOL Policy**: We aim to drop support 6-12 months after Ruby version EOL
