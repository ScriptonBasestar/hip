# .make Directory Guide

Quick reference for LLMs navigating Hip's modular Makefile structure.

---

## Overview

The `.make/` directory contains categorized Makefile fragments that are included by the main `Makefile`. This modular approach improves organization and maintainability by splitting 150+ lines into focused, single-responsibility files.

**Main Makefile**: Includes all `.make/*.mk` files using `-include` directive

---

## Files

| File | Lines | Purpose |
|------|-------|---------|
| `build.mk` | 16 | Build targets: build, clean, clobber |
| `install.mk` | 23 | Installation and bundling: install, reinstall, bundle, uninstall |
| `test.mk` | 13 | Test execution: test, test-fast, check |
| `lint.mk` | 11 | Code quality: lint, format (RuboCop) |
| `ci.mk` | 10 | CI/CD pipelines: pre-release, ci |
| `dev.mk` | 13 | Development tools: dev, console, version |
| `status.mk` | 18 | Status reporting: status (git, gems, version) |
| `hip-examples.mk` | 44 | Hip usage examples: hip-up, hip-down, hip-clean, etc. |
| `release.mk` | 6 | Release management: reset |
| `help.mk` | 11 | Help system: aggregates all targets from included makefiles |

**Total**: 165 lines

---

## Categories

### Build & Install (39 lines)
- **build.mk**: Gem building and artifact cleanup
- **install.mk**: Local installation, bundler management

### Development Workflow (31 lines)
- **dev.mk**: Quick development cycles, REPL, version check
- **status.mk**: Development status dashboard

### Quality Assurance (34 lines)
- **test.mk**: Test execution with coverage options
- **lint.mk**: Code linting and auto-fixing
- **ci.mk**: Pre-release checks

### Examples & Help (55 lines)
- **hip-examples.mk**: Demonstrate Hip usage in projects
- **help.mk**: Auto-generated help from all makefiles

### Maintenance (6 lines)
- **release.mk**: Clean slate reset

---

## Adding New Targets

### 1. Choose Appropriate File
Select the category that best fits your target's purpose.

### 2. Follow Existing Pattern
```makefile
.PHONY: my-target

my-target: ## Short description for help output
	@echo "Doing something..."
	@command-to-run
```

### 3. Add to `.PHONY` Declaration
Ensure target is declared as phony if it doesn't create a file.

### 4. Include Description
The `## description` format is parsed by `help.mk` for auto-generated help.

---

## Creating New Category

If none of the existing files fit:

1. Create `.make/category.mk`
2. Add `.PHONY` declarations
3. Add targets with `## descriptions`
4. Include in `Makefile`: `-include .make/category.mk`
5. Update this AGENTS.md

---

## Help System

The `help.mk` file aggregates all targets from included makefiles:

```bash
make help
# Shows all targets with descriptions, sorted alphabetically
```

**Implementation**:
- Greps for `target:.*?## description` pattern in all `.make/*.mk` files
- Formats output with color and alignment
- Automatically discovers new targets

---

## Best Practices

### DO
- ✅ Keep each file focused on a single category
- ✅ Use `@` prefix for quiet output (show only results)
- ✅ Add `## description` to all user-facing targets
- ✅ Declare all targets in `.PHONY`
- ✅ Use consistent naming conventions (kebab-case)

### DON'T
- ❌ Mix unrelated targets in same file
- ❌ Create targets without descriptions
- ❌ Duplicate target names across files
- ❌ Forget to include new `.mk` files in main Makefile
- ❌ Exceed ~50 lines per file (split if growing)

---

## File Size Guidelines

| Size | Status | Action |
|------|--------|--------|
| < 20 lines | ✅ Ideal | Maintain focus |
| 20-40 lines | ✅ Good | Monitor growth |
| 40-60 lines | ⚠️ Large | Consider splitting |
| > 60 lines | ⚠️ Too large | Split into subcategories |

**Current largest**: `hip-examples.mk` (44 lines) - acceptable due to many small targets

---

## Dependencies Between Targets

Some targets depend on others (executed via prerequisites or inline calls):

```makefile
# Prerequisite dependency
check: test lint

# Inline call dependency
reinstall: clean build install
```

**Cross-file dependencies** work automatically since all files are included in the same Makefile namespace.

---

## Testing Changes

After modifying any `.make/*.mk` file:

```bash
# Verify syntax
make -n target-name

# Test specific target
make target-name

# Verify help system
make help | grep target-name
```

---

## Examples

### Simple Target (lint.mk)
```makefile
lint: ## Run rubocop linter
	@echo "Running rubocop..."
	@bundle exec rubocop
```

### Composite Target (install.mk)
```makefile
reinstall: clean build install ## Clean, build, and reinstall hip gem
	@echo "✓ Hip reinstalled successfully"
	@hip --version
```

### Target with Arguments (hip-examples.mk)
```makefile
hip-rails: ## Run Rails commands via Hip (usage: make hip-rails ARGS="db:migrate")
	@hip rails $(ARGS)
```

---

## Migration Notes

**Previous structure**: Single `Makefile.dev.mk` (151 lines)

**New structure**: 10 categorized `.make/*.mk` files (165 lines total)

**Benefits**:
- Easier to find relevant targets
- Simpler to modify without conflicts
- Better organization for future growth
- Each file can be understood in isolation

**Compatibility**: All existing targets preserved with identical names and behavior
