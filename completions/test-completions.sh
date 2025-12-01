#!/usr/bin/env bash
# Script: test-completions.sh
# Purpose: Integration test for Hip shell completions
# Usage: ./completions/test-completions.sh [bash|zsh]
# Example: ./completions/test-completions.sh bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_TYPE="${1:-bash}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing Hip Shell Completions for ${SHELL_TYPE}${NC}"
echo ""

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}✗ jq not found - completions require jq${NC}"
    exit 1
fi
echo -e "${GREEN}✓ jq found${NC}"

# Check hip is available
if ! command -v hip &> /dev/null; then
    echo -e "${RED}✗ hip command not found${NC}"
    echo "  Install hip first: bundle exec rake install:local"
    exit 1
fi
echo -e "${GREEN}✓ hip command found${NC}"

# Test manifest generation
echo ""
echo -e "${BLUE}Testing manifest generation...${NC}"
if hip manifest --format json > /dev/null 2>&1; then
    echo -e "${GREEN}✓ hip manifest works${NC}"
else
    echo -e "${RED}✗ hip manifest failed${NC}"
    exit 1
fi

# Test manifest structure
echo ""
echo -e "${BLUE}Checking manifest structure...${NC}"
MANIFEST=$(hip manifest --format json)

# Check required fields
for field in hip_version schema_version static_commands dynamic_commands; do
    if echo "$MANIFEST" | jq -e ".$field" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Field '$field' present${NC}"
    else
        echo -e "${RED}✗ Field '$field' missing${NC}"
        exit 1
    fi
done

# Count available commands
STATIC_COUNT=$(echo "$MANIFEST" | jq '.static_commands | length')
DYNAMIC_COUNT=$(echo "$MANIFEST" | jq '.dynamic_commands | length')
echo ""
echo -e "${BLUE}Found $STATIC_COUNT static commands, $DYNAMIC_COUNT dynamic commands${NC}"

# Test completion script syntax
echo ""
echo -e "${BLUE}Testing completion script syntax...${NC}"

case "$SHELL_TYPE" in
    bash)
        if bash -n "$SCRIPT_DIR/hip.bash"; then
            echo -e "${GREEN}✓ Bash completion syntax valid${NC}"
        else
            echo -e "${RED}✗ Bash completion syntax error${NC}"
            exit 1
        fi
        ;;
    zsh)
        if zsh -n "$SCRIPT_DIR/_hip" 2>/dev/null; then
            echo -e "${GREEN}✓ Zsh completion syntax valid${NC}"
        else
            echo -e "${RED}✗ Zsh completion syntax error${NC}"
            exit 1
        fi
        ;;
    *)
        echo -e "${RED}Unknown shell type: $SHELL_TYPE${NC}"
        echo "Usage: $0 [bash|zsh]"
        exit 1
        ;;
esac

# Test completion source (non-interactive)
echo ""
echo -e "${BLUE}Testing completion script loading...${NC}"

case "$SHELL_TYPE" in
    bash)
        # Source the completion script in a subshell
        if bash -c "source '$SCRIPT_DIR/hip.bash' 2>/dev/null && type _hip_completion" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Bash completion function loads${NC}"
        else
            echo -e "${RED}✗ Bash completion function failed to load${NC}"
            exit 1
        fi
        ;;
    zsh)
        # Zsh completion loading test (basic check)
        if [[ -f "$SCRIPT_DIR/_hip" ]]; then
            echo -e "${GREEN}✓ Zsh completion file exists${NC}"
        else
            echo -e "${RED}✗ Zsh completion file not found${NC}"
            exit 1
        fi
        ;;
esac

# Test manifest cache
echo ""
echo -e "${BLUE}Testing manifest cache...${NC}"
CACHE_FILE="/tmp/hip-manifest-$USER.json"

# Remove old cache
rm -f "$CACHE_FILE"

# Trigger cache creation (simulate completion call)
if [[ "$SHELL_TYPE" == "bash" ]]; then
    bash -c "source '$SCRIPT_DIR/hip.bash' && _hip_get_manifest" > /dev/null 2>&1
    if [[ -f "$CACHE_FILE" ]]; then
        echo -e "${GREEN}✓ Manifest cache created${NC}"

        # Check cache content
        if jq -e '.static_commands' "$CACHE_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Cache content valid${NC}"
        else
            echo -e "${RED}✗ Cache content invalid${NC}"
            exit 1
        fi

        # Check cache age
        CACHE_AGE=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE")))
        echo -e "${BLUE}  Cache age: ${CACHE_AGE}s (TTL: 3600s)${NC}"
    else
        echo -e "${RED}✗ Manifest cache not created${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}All tests passed! ✓${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo "  1. Install completions: ./completions/install.sh"
echo "  2. Restart your shell"
echo "  3. Try: hip <TAB>"
echo ""
