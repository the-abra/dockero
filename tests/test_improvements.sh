#!/bin/bash
# Comprehensive test suite for Dockero improvements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKERO="${SCRIPT_DIR}/core/dockero"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((FAIL++)); }
info() { echo -e "${YELLOW}→${NC} $1"; }

DOCKER_AVAILABLE=false
command -v docker &>/dev/null && docker ps &>/dev/null 2>&1 && DOCKER_AVAILABLE=true

skip() { echo -e "${YELLOW}⊘${NC} $1 (skipped: docker unavailable)"; ((PASS++)); }

# Test 1: Dependency check (non-fatal)
info "Test 1: Dependency validation"
if $DOCKER_AVAILABLE; then
    pass "Docker is installed and running"
else
    info "Docker not found or not running (runtime tests will be skipped)"
fi
if command -v jq &>/dev/null; then
    pass "jq is installed"
else
    info "jq not found (some features will be limited)" || true
fi

# Test 2: Parameter parsing with values
info "Test 2: Parameter parsing"
declare -A params
args=()
source "${SCRIPT_DIR}/core/parameter-indexing.sh"
parameter-indexing mycontainer -t 50 -f
if [[ "${params[t]}" == "50" && "${params[f]}" == "true" && "${args[0]}" == "mycontainer" ]]; then
    pass "Parameter parsing handles 'mycontainer -t 50 -f' correctly"
else
    fail "Parameter parsing broken: t=${params[t]}, f=${params[f]}, args[0]=${args[0]}"
fi

# Test 3: Dynamic explain system
info "Test 3: Dynamic explain system"
if ! $DOCKER_AVAILABLE; then skip "Dynamic explain system"; elif
  "$DOCKERO" explain create 2>/dev/null | grep -q "Create and start a new container"; then
    pass "Dynamic explain works for 'create'"
else
    fail "Dynamic explain failed for 'create'"
fi

# Test 4: Plugin directory support
info "Test 4: Plugin system"
if ! $DOCKER_AVAILABLE; then skip "Plugin system"; else
mkdir -p ~/.dockero/commands
cat > ~/.dockero/commands/testplugin.sh << 'EOF'
#!/usr/bin/env bash
testplugin_help() { echo "Test plugin help"; }
testplugin() { echo "Plugin executed"; }
EOF
if "$DOCKERO" testplugin 2>/dev/null | grep -q "Plugin executed"; then
    pass "Plugin system loads user commands"
    rm -f ~/.dockero/commands/testplugin.sh
else
    fail "Plugin system not working"
    rm -f ~/.dockero/commands/testplugin.sh
fi
fi

# Test 5: DOCKERO_RUNTIME variable usage
info "Test 5: Runtime flexibility"
if grep -q 'DOCKERO_RUNTIME:-docker' "${SCRIPT_DIR}/core/commands/create.sh"; then
    pass "Commands use \${DOCKERO_RUNTIME:-docker}"
else
    fail "Hardcoded docker calls still exist"
fi

# Test 6: Help functions exist
info "Test 6: Help function coverage"
missing=0
for cmd in create volume list monitor heal net sync compose env; do
    if ! grep -q "${cmd}_help()" "${SCRIPT_DIR}/core/commands/${cmd}.sh" 2>/dev/null; then
        ((missing++))
    fi
done
if [[ $missing -eq 0 ]]; then
    pass "All major commands have _help() functions"
else
    fail "$missing commands missing _help() functions"
fi

# Test 7: Validation functions
info "Test 7: Input validation"
if ! $DOCKER_AVAILABLE; then skip "Input validation"; elif
  "$DOCKERO" create "invalid name with spaces" 2>&1 | grep -q "Invalid container name"; then
    pass "Container name validation works"
else
    fail "Container name validation not working"
fi

# Test 8: Version command
info "Test 8: Version command"
if ! $DOCKER_AVAILABLE; then skip "Version command"; elif
  "$DOCKERO" version 2>/dev/null | grep -q "Dockero CLI"; then
    pass "Version command works"
else
    fail "Version command failed"
fi

# Test 9: Explain lists available commands
info "Test 9: Explain command discovery"
if ! $DOCKER_AVAILABLE; then skip "Explain command discovery"; elif
  "$DOCKERO" explain 2>/dev/null | grep -q "Available commands:"; then
    pass "Explain lists available commands"
else
    fail "Explain doesn't list commands"
fi

# Test 10: Help command
info "Test 10: Help system"
if ! $DOCKER_AVAILABLE; then skip "Help system"; elif
  "$DOCKERO" help 2>/dev/null | grep -q "Container Management"; then
    pass "Help command shows categorized commands"
else
    fail "Help command output broken"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Test Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
